"use client";
import { useState, useEffect } from "react"; // 1. 状態管理の道具をインポート

export default function Home() {
	const [repos, setRepos] = useState([]); // 2. 取得したリポジトリを入れる箱
	
	// 3. GitHub APIを叩く関数（インフラでいう curl コマンドのJavaScript版）
  useEffect(() => {
    const fetchRepos = async () => {
      // あなたのGitHubユーザー名に変えてみてください！
      const response = await fetch("https://api.github.com/users/masaki-y-devops/repos?sort=updated");
      const data = await response.json();
      setRepos(data.slice(0, 4)); // 直近更新の4つだけ取得
    };
    fetchRepos();
  }, []);
  
  // 1. スキルデータの配列（ここに新しいスキルを追加すれば自動で増えます）
  const skills = [
    { name: "Linux / Shell", level: "Advanced" },
    { name: "Docker / K8s", level: "Intermediate" },
    { name: "Next.js / React", level: "Learning" },
    { name: "Tailwind CSS", level: "Beginner" },
	{ name: "OCI", level: "Beginner" },
	{ name: "AWS", level: "Beginner" },
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
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            
            {/* 2. mapを使ってループ処理 */}
            {skills.map((skill) => (
              <div key={skill.name} onClick={() => alert(`${skill.name}を学習中です！`)} className="bg-white p-4 rounded-lg shadow-sm border border-slate-200 flex items-center justify-between cursor-pointer hover:shadow-md transition-shadow">
                <div>
                  <h3 className="font-bold">{skill.name}</h3>
                </div>

                {/* 3. ここが「条件分岐」の魔法！レベルによって背景色を変える */}
                <span className={`px-3 py-1 rounded-full text-white text-xs font-bold ${
                  skill.level === "Advanced" ? "bg-red-500" : 
                  skill.level === "Intermediate" ? "bg-green-500" : 
				  skill.level === "Learning" ? "bg-blue-500" :
                  "bg-slate-400"
                }`}>
                  {skill.level}
                </span>

              </div>
            ))}

          </div>
        </section>
		
		<section className="mt-12">
          <h2 className="text-xl font-bold mb-6 border-b-2 border-indigo-200 pb-2">GitHub Repositories</h2>
          <div className="grid grid-cols-1 gap-4">
            {repos.map((repo: any) => (
              <a 
                key={repo.id} 
                href={repo.html_url} 
                target="_blank" 
                className="block bg-white p-4 rounded-lg shadow-sm border border-slate-200 hover:border-indigo-400 transition-colors"
              >
                <h3 className="font-bold text-indigo-600">{repo.name}</h3>
                <p className="text-sm text-slate-500">{repo.description || "No description"}</p>
                <div className="mt-2 text-xs text-slate-400">⭐ {repo.stargazers_count} | Language: {repo.language}</div>
              </a>
            ))}
          </div>
        </section>
      </div>
    </main>
  );
}