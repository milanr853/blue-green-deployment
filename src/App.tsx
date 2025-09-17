import './App.css'

export default function App() {
  const version = import.meta.env.VITE_APP_VERSION || "local-dev";
  const color = import.meta.env.VITE_DEPLOYMENT_COLOR || "unknown"; // injected by k8s

  return (
    <div className={`min-h-screen flex items-center justify-center ${color === "blue" ? "bg-blue-50" : "bg-green-50"}`}>
      <div className="p-8 rounded-lg shadow-lg bg-white max-w-xl text-center">
        <h1 className="text-3xl font-bold mb-4">Blue/Green Deployment Live</h1>
        <div className="text-sm text-slate-500">Build version: <strong>{version}</strong></div>
        <div className="text-sm text-slate-500">Deployment: <strong>{color}</strong></div>
      </div>
    </div>
  );
}
