// server-express.js
const express = require('express')
const app = express() // アプリの初期化
const port = 3000

// GETコールバック関数がレスポンスメッセージを返す
app.get('/', (req, res) => {
res.send('Hello World! Welcome to Node.js')
})

app.listen(port, () => {
console.log(`Server listening at http://localhost:${port}`)
})