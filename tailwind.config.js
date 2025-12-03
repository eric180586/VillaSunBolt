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
          50: '#FDF6EC',
          100: '#F5E7D7',
          200: '#E8D3B8',
          300: '#DDC1A0',
          400: '#CFA57E',
          500: '#C0915F',
          600: '#A47754',
          700: '#856043',
          800: '#6B4D36',
          900: '#59402C',
        },
      },
    },
  },
  plugins: [],
};
