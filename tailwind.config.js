/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}", // ganz wichtig, damit alle Komponenten abgedeckt sind!
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
