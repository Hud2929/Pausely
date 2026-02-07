import { useState } from 'react'

const steps = [
  {
    number: '01',
    title: 'Add',
    description: 'Manually add your subscriptions to track them all in one place.',
  },
  {
    number: '02',
    title: 'Analyze',
    description: 'Our AI analyzes your subscriptions and finds savings opportunities.',
  },
  {
    number: '03',
    title: 'Optimize',
    description: 'See free perks you already have access to and unused subscriptions.',
  },
  {
    number: '04',
    title: 'Save',
    description: 'Pause, cancel, or switch to save money with AI assistance.',
  },
]

export default function HowItWorks() {
  const [activeStep, setActiveStep] = useState(0)

  return (
    <section id="how-it-works" className="section">
      <div className="container max-w-5xl">
        {/* Header */}
        <div className="text-center mb-28">
          <p className="caption mb-6">How It Works</p>
          <h2 className="headline-medium mb-8">
            Four steps to savings.
          </h2>
          <p className="body-large max-w-md mx-auto">
            Get started in minutes. No credit card required.
          </p>
        </div>

        {/* Steps */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-8">
          {steps.map((step, index) => {
            const isActive = index === activeStep

            return (
              <button
                key={index}
                onClick={() => setActiveStep(index)}
                className={`text-left p-8 rounded-3xl transition-all duration-300 ${
                  isActive ? 'glass' : 'hover:bg-white/[0.02]'
                }`}
              >
                <span className="text-sm text-white/30 font-semibold tracking-wider">{step.number}</span>
                <h3 className="text-2xl font-semibold mt-4 mb-4">{step.title}</h3>
                <p className="text-white/40 leading-relaxed">{step.description}</p>
              </button>
            )
          })}
        </div>

        {/* Progress Dots */}
        <div className="mt-20 flex justify-center gap-3">
          {steps.map((_, index) => (
            <button
              key={index}
              onClick={() => setActiveStep(index)}
              className={`h-1.5 rounded-full transition-all duration-300 ${
                index === activeStep ? 'w-10 bg-white' : 'w-1.5 bg-white/20 hover:bg-white/40'
              }`}
            />
          ))}
        </div>
      </div>
    </section>
  )
}
