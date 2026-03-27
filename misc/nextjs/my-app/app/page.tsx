"use client";

export default function Home() {
  return (
    // min-h-screen: 画面全体の高さ / bg-slate-50: 薄いグレーの背景 / bg-orange-100
    <main className="min-h-screen bg-orange-100 p-8">
      
      {/* max-w-2xl: 幅を制限 / mx-auto: 中央寄せ / bg-white: 白背景 / rounded-xl: 角丸 / shadow-lg: 影 */}
      <div className="max-w-2xl mx-auto bg-white p-10 rounded-xl shadow-lg border border-slate-200">
        
        {/* text-3xl: 文字サイズ / font-bold: 太字 / text-indigo-600: 濃い青紫 */}
        <h1 className="text-3xl font-bold text-indigo-600 mb-4">
          My Frontend Journey
        </h1>
        
        <p className="text-slate-600 mb-6 leading-relaxed">
          インフラエンジニアからフロントエンドへ。
          Next.js と Tailwind CSS で構築した最初のポートフォリオです。
        </p>

        {/* Flexboxで横並び: gap-4で間隔をあける */}
        <div className="flex gap-4">
          <button 
            onClick={() => alert('Deployed on Vercel!')}
            className="px-6 py-2 bg-indigo-600 text-white rounded-lg font-medium hover:bg-indigo-700 transition-colors"
          >
            Vercelの状態を確認
          </button>

          <button 
            className="px-6 py-2 border border-slate-300 text-slate-600 rounded-lg font-medium hover:bg-slate-50 transition-colors"
          >
            GitHubを見る
          </button>
        </div>

      </div>
    </main>
  );
}
