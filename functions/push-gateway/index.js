const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Admin SDK once
try {
  admin.initializeApp();
} catch (e) {}

// HTTP endpoint to send push notification by FCM token
exports.sendPush = functions.https.onRequest(async (req, res) => {
  // Allow only POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }
  try {
    const { token, title, body, data } = req.body || {};
    if (!token || !title || !body) {
      return res.status(400).json({ error: 'Missing token/title/body' });
    }

    const message = {
      token,
      notification: { title, body },
      data: data || {},
      android: { priority: 'high' },
      apns: { headers: { 'apns-priority': '10' } },
    };

    const response = await admin.messaging().send(message);
    return res.status(200).json({ success: true, messageId: response });
  } catch (err) {
    console.error('sendPush error', err);
    return res.status(500).json({ success: false, error: err.message || String(err) });
  }
});


