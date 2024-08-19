const app = require('express')();
const server = require('http').createServer(app);
const options = { /* ... */ };
const io = require('socket.io')(server, options);

app.get('/', (req, res) => {
    res.send('Hello World Nodejs....')
})
//Device ID to emit and on from and to sensor-server-user
io.on('connection', client => {
    console.log(`New client connected`);
    client.on('SensorToServer', data => {
        console.log(data);
        // let dht = eval(data);
        // console.log(dht.dht.tempC);
        io.emit("ServerToUser", data)
    })
    
    client.on("from-user", data =>{
        console.log(data);
    })
    
    client.on("TurnOnOff", data => {
        console.log(data)
        io.emit("ServerToSensor", data)
    })

    client.on("UpdateHistory", () => {
        io.emit("AppUpdate")
    })

    client.on("WaterByHand", () => {
        io.emit("HandWater")
    })

    client.on('disconnect', () => console.log(`Client disconnected`))
});

const PORT = 80;
server.listen(process.env.PORT || PORT, () => {
    console.log(`Example app listening at http://localhost:${PORT}`)
})