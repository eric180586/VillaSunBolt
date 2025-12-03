// src/main.tsx

import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

// Das ist der Einstiegspunkt für die gesamte App!
// Stelle sicher, dass du im public/index.html ein <div id="root"></div> hast.

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
