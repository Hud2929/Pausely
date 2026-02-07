import { ArrowRight } from 'lucide-react'

export default function Hero() {
  const scrollToCTA = () => {
    document.querySelector('#cta')?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section className="relative min-h-screen flex items-center justify-center pt-20">
      {/* Subtle Background */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-blue-500/5 rounded-full blur-3xl" />
        <div className="absolute bottom-1/4 left-1/4 w-[400px] h-[400px] bg-purple-500/5 rounded-full blur-3xl" />
      </div>

      <div className="container relative z-10">
        <div className="max-w-4xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 mb-10">
            <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
            <span className="text-sm text-white/70">Now with AI insights</span>
          </div>

          {/* Headline */}
          <h1 className="headline-xl mb-6">
            Stop overpaying.
          </h1>

          <p className="body-large text-xl mb-12 max-w-xl mx-auto">
            Find and optimize your subscriptions. 
            The average user saves $127/month.
          </p>

          {/* CTA */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <button onClick={scrollToCTA} className="btn-primary">
              Start Free Trial
              <ArrowRight className="w-5 h-5 ml-2" />
            </button>
            <button onClick={scrollToCTA} className="btn-secondary">
              Learn More
            </button>
          </div>

          {/* Stats - Minimal */}
          <div className="mt-24 grid grid-cols-3 gap-8 max-w-lg mx-auto">
            {[
              { value: '$127', label: 'Saved monthly' },
              { value: '5 min', label: 'To start' },
              { value: '10K+', label: 'Users' },
            ].map((stat) => (
              <div key={stat.label} className="text-center">
                <p className="text-3xl font-semibold mb-1">{stat.value}</p>
                <p className="text-sm text-white/50">{stat.label}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
