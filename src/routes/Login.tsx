import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../lib/supabaseClient";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [mode, setMode] = useState<"login" | "register">("login");

  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      let result;
      if (mode === "login") {
        result = await supabase.auth.signInWithPassword({ email, password });
      } else {
        result = await supabase.auth.signUp({ email, password });
      }

      if (result.error) {
        setError(result.error.message);
      } else if (result.data?.user || result.data?.session) {
        navigate("/dashboard");
      } else if (mode === "register") {
        setError("Bestätige deine E-Mail, um dich einzuloggen.");
      }
    } catch (err: any) {
      setError(err.message || "Unbekannter Fehler");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col justify-center items-center bg-gradient-to-br from-yellow-50 via-orange-100 to-yellow-200">
      <div className="w-full max-w-md rounded-2xl shadow-lg bg-white p-8">
        <h2 className="text-2xl font-bold mb-4 text-center">
          {mode === "login" ? "Login" : "Registrieren"}
        </h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            className="w-full p-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-yellow-400"
            type="email"
            placeholder="E-Mail"
            value={email}
            onChange={e => setEmail(e.target.value)}
            required
          />
          <input
            className="w-full p-3 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-yellow-400"
            type="password"
            placeholder="Passwort"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
          />
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-yellow-400 text-white font-bold rounded-xl hover:bg-yellow-500 transition disabled:bg-yellow-200"
          >
            {loading ? "Bitte warten..." : mode === "login" ? "Login" : "Registrieren"}
          </button>
        </form>
        {error && (
          <div className="mt-3 text-center text-red-600">{error}</div>
        )}
        <div className="mt-5 text-center">
          {mode === "login" ? (
            <span>
              Noch kein Account?{" "}
              <button
                onClick={() => setMode("register")}
                className="text-yellow-600 underline"
              >
                Jetzt registrieren
              </button>
            </span>
          ) : (
            <span>
              Bereits Account?{" "}
              <button
                onClick={() => setMode("login")}
                className="text-yellow-600 underline"
              >
                Zum Login
              </button>
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
