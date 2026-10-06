const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
const { ObjectId } = require('mongodb');

// Initialize Firebase (wrapped in try-catch to prevent re-init errors)
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const sendNewLeadNotification = async (lead, dataUser, db) => {
    try {
        console.log(`[FCM] Sending Business Alert / New Lead Notification to agents...`);

        // 1. Fetch ALL Agent / Admin Users and users with FCM Tokens
        let users = await db.collection('users').find({
            $or: [
                { role: { $in: ['agent', 'admin', 'superadmin', 'Agent', 'Admin'] } },
                { fcmToken: { $exists: true, $ne: null, $ne: "" } },
                { isAgent: true }
            ]
        }).toArray();

        if (!users || users.length === 0) {
            users = await db.collection('users').find({}).toArray();
        }

        console.log(`[FCM] Target agent/admin count: ${users.length}`);

        // 2. Prepare Notification Content
        const creatorName = (dataUser && (dataUser.username || dataUser.name || (dataUser.email && dataUser.email.split('@')[0]))) || "System";
        const companyName = (lead && (lead.company || lead.Company)) || "No Company";
        const leadName = (lead && (lead.Name || lead.name || lead.contactName)) || "New Lead";
        const leadIdStr = lead && (lead._id || lead.id) ? (lead._id || lead.id).toString() : '';

        const title = 'Business Alert: New Lead Created!';
        const body = `Lead: ${leadName}\nBy: ${creatorName} | Co: ${companyName}`;

        // 3. Send to EACH target agent / user
        for (const user of users) {
            // ALWAYS insert notification into DB so agent sees it in notifications panel & poller
            try {
                await db.collection('notifications').insertOne({
                    title,
                    body,
                    type: "business_alert",
                    data: {
                        leadId: leadIdStr,
                        actionType: 'NEW_LEAD',
                        timestamp: new Date()
                    },
                    sender: "system",
                    recipient: user._id,
                    isRead: false,
                    sentAt: new Date(),
                    createdAt: new Date(),
                    updatedAt: new Date()
                });
            } catch (dbErr) {
                console.error(`[FCM] Error inserting DB notification for ${user.email || user._id}:`, dbErr.message);
            }

            // Send Firebase FCM Push Notification if fcmToken is available
            if (user.fcmToken) {
                const message = {
                    notification: {
                        title: title,
                        body: body,
                    },
                    data: {
                        leadId: leadIdStr,
                        actionType: 'NEW_LEAD',
                        click_action: 'FLUTTER_NOTIFICATION_CLICK'
                    },
                    token: user.fcmToken
                };

                try {
                    await admin.messaging().send(message);
                    console.log(`[FCM] Push sent to ${user.email}`);
                } catch (err) {
                    console.error(`[FCM] ❌ FCM push error for ${user.email}:`, err.message);
                }
            } else {
                console.log(`[FCM] ℹ️ Agent ${user.email || user._id} notification saved to DB (no FCM token).`);
            }
        }

    } catch (error) {
        console.error('Error sending notification:', error);
    }
};

const sendBusinessAlertNotification = async (title, body, payloadData, db) => {
    try {
        let users = await db.collection('users').find({
            $or: [
                { role: { $in: ['agent', 'admin', 'superadmin', 'Agent', 'Admin'] } },
                { fcmToken: { $exists: true, $ne: null, $ne: "" } },
                { isAgent: true }
            ]
        }).toArray();

        if (!users || users.length === 0) {
            users = await db.collection('users').find({}).toArray();
        }

        for (const user of users) {
            try {
                await db.collection('notifications').insertOne({
                    title,
                    body,
                    type: "business_alert",
                    data: { ...payloadData, timestamp: new Date() },
                    sender: "system",
                    recipient: user._id,
                    isRead: false,
                    sentAt: new Date(),
                    createdAt: new Date(),
                    updatedAt: new Date()
                });
            } catch (e) {}

            if (user.fcmToken) {
                try {
                    await admin.messaging().send({
                        notification: { title, body },
                        data: payloadData || {},
                        token: user.fcmToken
                    });
                } catch (err) {}
            }
        }
    } catch (err) {
        console.error('Error sending business alert:', err);
    }
};

module.exports = { sendNewLeadNotification, sendBusinessAlertNotification };