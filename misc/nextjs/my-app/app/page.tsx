"use client";

import Image from "next/image";

export default function Home() {
  return (
   <main style={{ padding: '50px', textAlign: 'center' }}>
      <h1>こんにちは、フロントエンドの世界へ！</h1>
      <p>これは僕が初めてNext.jsで動かした画面です。</p>
      <button onClick={() => alert('動いた！')}>ボタンを押してみて</button>
    </main>
  );
}
