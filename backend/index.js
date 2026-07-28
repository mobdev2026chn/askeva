const express = require("express");
const cors = require("cors");
require("express-async-errors");
const { MongoClient } = require("mongodb");
const routes = require("./routes/index");
const timeout = require("connect-timeout");
require("dotenv").config();
const fs = require("fs");
const { Queue } = require("bullmq");
const IORedis = require("ioredis");

let chalk;
import("chalk").then(module => {
  chalk = module.default;
});
const clientSocket = require("./Socket");
const createHttpError = require("http-errors");
const client = new MongoClient(process.env.MONGO_URL, {
  minPoolSize: 10,
  maxPoolSize: 40,
  maxIdleTimeMS: 30000,
});
const PORT = process.env.PORT || 2000;
const app = express();
app.set("trust proxy", [
  "loopback",
  "linklocal",
  "uniquelocal",
  "10.0.0.0/8",
  "172.16.0.0/12",
  "192.168.0.0/16",
]);

async function run() {
  try {
    let connection = await client.connect();
    console.log("Client connected successfully");

    const bullRedisConnection = new IORedis({
      host: "134.209.159.202",
      port: 6379,
      maxRetriesPerRequest: null,
      // Add password if your Redis server requires authentication
      // password: process.env.REDIS_PASSWORD,
    })
      .on("connect", () => console.log("Bullmq Client Connected"))
      .on("error", err => console.log("Bullmq Client Error", err));

    const messageQueue = new Queue("cron-messages", {
      connection: bullRedisConnection,
    });

    ["SIGINT", "SIGTERM"].forEach(signal => {
      process.on(signal, () => {
        console.log(`Process ${signal} received`);
        connection.close();
        bullRedisConnection.quit();
        process.exit(0);
      });
    });

    if (!fs.existsSync(process.env.TEMP_DIR)) {
      fs.mkdirSync(process.env.TEMP_DIR);
    }

    const ping = await connection
      .db(process.env.SUPER_ADMIN_DB)
      .command({ ping: 1 });

    if (ping.ok) {
      app.use(cors());

      app.use("/", (req, res, next) => {
        const start = process.hrtime();

        res.on("finish", () => {
          const diff = process.hrtime(start);
          const responseTime = (diff[0] * 1e9 + diff[1]) / 1e6;
          const responseTimeStr = responseTime.toFixed(3);

          if (responseTime > 100) {
            console.log(
              chalk.red(
                `${req.method} ${req.originalUrl} [${res.statusCode}] - ${responseTimeStr} ms`
              )
            );
          } else {
            console.log(
              chalk.green(
                `${req.method} ${req.originalUrl} [${res.statusCode}] - ${responseTimeStr} ms`
              )
            );
          }
        });

        next();
      });
      app.use(timeout("30s"));

      app.use(express.json({ limit: "50mb" }));
      app.use(express.urlencoded({ limit: "50mb", extended: true }));

      app.use("/", (req, res, next) => {
        req.dbConnect = connection;
        req.messageQueue = messageQueue;
        req["socketio"] = clientSocket;
        next();
      });

      app.use("/v1", routes);

      app.use((req, res, next) => {
        next(createHttpError(404));
      });

      app.use((err, req, res, next) => {
        res.status(err.status || 500).json({
          error: {
            status: err.status || 500,
            msg: err.message || "Internal Server Error",
          },
        });
      });

      app.listen(PORT, () => {
        console.log(`Server is running on port: ${PORT}`);
      });
    } else {
      console.error("Error connecting to MongoDB");
      connection.close();
    }
  } catch (error) {
    console.error("Error connecting to MongoDB", error);
    client.close();
  }
}

run().catch(console.dir);
