const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');

const app = express();
app.use(cors());

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
  }
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // User joins with their userId
  socket.on('register', (userId) => {
    socket.userId = userId;
    socket.join(userId); // join room with userId
    console.log(`User registered: ${userId}`);
  });

  // Send message
  socket.on('send_message', (data) => {
    const { to, messageId, text } = data;
    // Forward to receiver only
    io.to(to).emit('receive_message', { messageId, text, from: socket.userId });
    // Optional: log message temporarily, but don't store
  });

  // ACK for delivered
  socket.on('message_delivered', (data) => {
    console.log('Message delivered:', data.messageId);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

server.listen(3000, () => console.log('Socket.IO server running on port 3000'));
