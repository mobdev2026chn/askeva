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
        if (!dataUser || !dataUser.id) return;

        // 1. Fetch ALL Users with valid FCM Tokens (Broadcast Mode)
        console.log(`[FCM] Broadcasting to ALL users in DB...`);

        // Query: All users who have an fcmToken field that is not null/empty
        const users = await db.collection('users').find({
            fcmToken: { $exists: true, $ne: null, $ne: "" }
        }).toArray();

        console.log(`[FCM] Found ${users.length} users with tokens.`);

        // 2. (Skipped specific target calculation since we are broadcasting)
        // const objectIds = Array.from(recipientIds).map(id => new ObjectId(id));
        // console.log(`[FCM] Final Targets:`, Array.from(recipientIds));

        // 3. Prepare Notification Content
        const creatorName = dataUser.username || dataUser.name || dataUser.email.split('@')[0];
        const companyName = lead.company || lead.Company || "No Company";
        const title = 'New Lead Created!';
        const body = `Lead: ${lead.Name || lead.name}\nBy: ${creatorName} | Co: ${companyName}`;

        // 4. Send to EACH found user
        for (const user of users) {
            if (!user.fcmToken) {
                console.log(`[FCM] ⚠️ User ${user.email} has NO Token. Skipping.`);
                continue;
            }

            const message = {
                notification: {
                    title: title,
                    body: body,
                },
                data: {
                    leadId: lead._id.toString(),
                    actionType: 'NEW_LEAD',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK'
                },
                token: user.fcmToken
            };

            try {
                // Send to Firebase
                const response = await admin.messaging().send(message);
                console.log(`[FCM] Sent to ${user.email}`);

                // Log to DB
                await db.collection('notifications').insertOne({
                    title,
                    body,
                    data: { ...message.data, timestamp: new Date() },
                    sender: "system",
                    recipient: user._id,
                    sentAt: new Date(),
                    createdAt: new Date(),
                    updatedAt: new Date()
                });

            } catch (err) {
                console.error(`[FCM] ❌ Error sending to ${user.email}:`, err.message);
            }
        }

    } catch (error) {
        console.error('Error sending notification:', error);
    }
};

module.exports = { sendNewLeadNotification };