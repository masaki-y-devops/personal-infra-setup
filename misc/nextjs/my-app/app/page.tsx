"use client";

export default function Home() {
  // 1. あなたのスキルセットを「データ」として定義
  const skills = [
    { name: "Linux / Shell", level: "Advanced", color: "bg-slate-800" },
    { name: "Docker / K8s", level: "Intermediate", color: "bg-blue-600" },
    { name: "Next.js / React", level: "Learning", color: "bg-black" },
    { name: "Tailwind CSS", level: "Beginner", color: "bg-cyan-500" },
    { name: "Vercel / CI/CD", level: "Beginner", color: "bg-indigo-500" },
  ];

  return (
    <main className="min-h-screen bg-slate-50 p-8 text-slate-900">
      <div className="max-w-3xl mx-auto">
        <header className="mb-12 text-center">
          <h1 className="text-4xl font-extrabold text-indigo-700 mb-2">Engineer Portfolio</h1>
          <p className="text-slate-500">Infrastructure & Frontend Journey</p>
        </header>

        <section>
          <h2 className="text-xl font-bold mb-6 border-b-2 border-indigo-200 pb-2">Technical Skills</h2>
          
          {/* 2. グリッドレイアウト（レスポンシブ：スマホ1列、PC2列） */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            
            {/* 3. 配列(skills)をループしてカードを生成 */}
            {skills.map((skill) => (
              <div key={skill.name} className="bg-white p-4 rounded-lg shadow-sm border border-slate-200 flex items-center justify-between">
                <div>
                  <h3 className="font-bold">{skill.name}</h3>
                  <p className="text-xs text-slate-400">{skill.level}</p>
                </div>
                {/* 動的に色を変える */}
                <span className={`px-3 py-1 rounded-full text-white text-xs ${skill.color}`}>
                  Active
                </span>
              </div>
            ))}

          </div>
        </section>

        <footer className="mt-12 text-center text-slate-400 text-sm">
          <p>© 2024 Built with Next.js & Vercel</p>
        </div>
      </div>
    </main>
  );
}