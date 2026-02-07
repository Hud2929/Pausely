import { useState } from 'react'

const steps = [
  {
    number: '01',
    title: 'Connect',
    description: 'Link your bank accounts securely.',
  },
  {
    number: '02',
    title: 'Discover',
    description: 'We find all your subscriptions.',
  },
  {
    number: '03',
    title: 'Optimize',
    description: 'See free perks you already have.',
  },
  {
    number: '04',
    title: 'Save',
    description: 'Pause or switch to save money.',
  },
]

export default function HowItWorks() {
  const [activeStep, setActiveStep] = useState(0)

  return (
    <section id="how-it-works" className="section bg-[#050505]">
      <div className="container">
        <div className="max-w-4xl mx-auto">
          {/* Header */}
          <div className="text-center mb-20">
            <p className="caption mb-4">How It Works</p>
            <h2 className="headline-medium">
              Four steps to savings.
            </h2>
          </div>

          {/* Steps */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            {steps.map((step, index) => {
              const isActive = index === activeStep

              return (
                <button
                  key={index}
                  onClick={() => setActiveStep(index)}
                  className={`text-left p-6 rounded-2xl transition-all duration-300 ${
                    isActive ? 'bg-white/5' : 'hover:bg-white/[0.02]'
                  }`}
                >
                  <span className="text-sm text-white/30 font-medium">{step.number}</span>
                  <h3 className="text-xl font-semibold mt-2 mb-2">{step.title}</h3>
                  <p className="text-white/40 text-sm">{step.description}</p>
                </button>
              )
            })}
          </div>

          {/* Progress */}
          <div className="mt-12 flex justify-center gap-2">
            {steps.map((_, index) => (
              <button
                key={index}
                onClick={() => setActiveStep(index)}
                className={`h-1 rounded-full transition-all ${
                  index === activeStep ? 'w-8 bg-white' : 'w-1 bg-white/20'
                }`}
              />
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
