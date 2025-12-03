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
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        beige: {
          50: "#faf8f5",
          100: "#f3eee6",
          200: "#e6ded1",
          800: "#6b5c4e",
          900: "#554233"
        }
      }
    }
  },
  plugins: [],
}
