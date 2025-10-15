export default function Home() {
  return (
    <div className="font-sans grid grid-rows-[20px_1fr_20px] items-center justify-items-center min-h-screen p-8 pb-20 gap-16 sm:p-20">
      <h1>Hello Next.js!</h1>
      
      <p className="text-center max-w-lg">
        This is a minimal Next.js app deployed with Docker. You can start editing the code in <code>src/app/page.tsx</code>.
      </p>

      <p className="text-center max-w-lg">
        This app is a great starting point for building modern web applications with Next.js and Docker.
      </p>

      <footer className="text-xs text-center text-gray-500">
        Deployed with ❤️ using Docker
      </footer>
    </div>
  )
}
