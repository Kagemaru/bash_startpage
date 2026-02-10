/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        // Example: Matrix theme colors
        matrix: {
          green: '#00ff41',
          dark: '#0d0208',
        }
      },
    },
  },
  plugins: [],
}
