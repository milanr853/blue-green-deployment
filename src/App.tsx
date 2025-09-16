import './App.css'


export default function App() {
  const version = import.meta.env.VITE_APP_VERSION || "local-dev";
  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50">
      <div className="p-8 rounded-lg shadow-lg bg-white max-w-xl text-center">
        <h1 className="text-3xl font-bold mb-4">Blue/Green Demo</h1>

        <div className="text-sm text-slate-500">Build version: <strong>{version}</strong></div>
      </div>
    </div>
  );
}
