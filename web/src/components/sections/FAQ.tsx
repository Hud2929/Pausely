import { useState } from 'react'
import { ChevronDown } from 'lucide-react'

const faqs = [
  {
    question: 'How does Pausely find my subscriptions?',
    answer: 'Pausely uses secure bank-level connections (via Plaid) to analyze your transaction history. Our AI identifies recurring charges and categorizes them as subscriptions. We can detect subscriptions even if the merchant name varies or if they bill annually.'
  },
  {
    question: 'Is my financial data safe?',
    answer: 'Absolutely. We use AES-256 encryption for all data, the same standard banks use. We never store your bank login credentials — authentication is handled securely through Plaid. We\'re SOC 2 Type II compliant and undergo regular third-party security audits.'
  },
  {
    question: 'What\'s the difference between pausing and canceling?',
    answer: 'Pausing temporarily suspends your subscription while keeping your account, data, and preferences intact. You can resume instantly. Canceling permanently closes your account. Many services (Netflix, Spotify, gym memberships) allow pausing but hide the option. We find it for you.'
  },
  {
    question: 'How do you find free alternatives?',
    answer: 'We maintain a database of perks from credit cards, employers, libraries, and memberships. We cross-reference your subscriptions with perks you already have access to. For example, your Chase Sapphire might include free DashPass, or your library card might unlock Kanopy streaming.'
  },
  {
    question: 'Can I use Pausely outside the US?',
    answer: 'Currently, Pausely supports US and Canadian bank accounts. We\'re working on expanding to UK, EU, and Australia. Sign up for our waitlist to be notified when we launch in your country.'
  },
  {
    question: 'What if I want to cancel the subscription I\'m paying for?',
    answer: 'You can! Pausely provides direct links to cancellation pages and even generates cancellation scripts for services that require phone calls or emails. We make the process as painless as possible.'
  },
  {
    question: 'Is there a free trial?',
    answer: 'Yes! Every plan starts with a 14-day free trial. No credit card required. You can upgrade, downgrade, or cancel anytime. If you choose not to continue, your data is automatically deleted after 30 days.'
  },
  {
    question: 'How accurate is the cost-per-hour calculation?',
    answer: 'We integrate with your device\'s Screen Time (with your permission) to track actual app usage. For services without Screen Time data, we use intelligent estimates based on industry averages and your billing patterns. You can always manually adjust usage data.'
  }
]

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(0)

  const toggleFAQ = (index: number) => {
    setOpenIndex(openIndex === index ? null : index)
  }

  return (
    <section id="faq" className="section-small bg-[#0a0a0a]">
      <div className="container max-w-4xl">
        {/* Header */}
        <div className="text-center mb-16">
          <p className="caption mb-4">FAQ</p>
          <h2 className="headline-medium mb-6">
            Questions?{' '}
            <span className="gradient-text">We have answers.</span>
          </h2>
          <p className="body-large">
            Everything you need to know about Pausely. Can't find what you're looking for? 
            <a href="#cta" className="text-blue-400 hover:underline">Contact us</a>.
          </p>
        </div>

        {/* FAQ List */}
        <div className="space-y-4">
          {faqs.map((faq, index) => (
            <div
              key={index}
              className="bg-[#1c1c1e] rounded-2xl border border-white/5 overflow-hidden"
            >
              <button
                onClick={() => toggleFAQ(index)}
                className="w-full flex items-center justify-between p-6 text-left hover:bg-white/5 transition-colors"
              >
                <span className="text-lg font-medium pr-8">{faq.question}</span>
                <div className={`flex-shrink-0 w-8 h-8 rounded-full bg-white/5 flex items-center justify-center transition-all ${
                  openIndex === index ? 'bg-blue-500/20 rotate-180' : ''
                }`}>
                  <ChevronDown className={`w-5 h-5 transition-colors ${
                    openIndex === index ? 'text-blue-400' : 'text-white/40'
                  }`} />
                </div>
              </button>
              
              <div
                className={`overflow-hidden transition-all duration-300 ${
                  openIndex === index ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0'
                }`}
              >
                <div className="px-6 pb-6 text-white/60 leading-relaxed">
                  {faq.answer}
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Still Have Questions */}
        <div className="mt-16 text-center p-8 rounded-3xl bg-gradient-to-br from-blue-500/10 to-purple-500/10 border border-white/5">
          <h3 className="text-xl font-semibold mb-2">Still have questions?</h3>
          <p className="text-white/60 mb-6">Can't find the answer you're looking for? Please chat with our friendly team.</p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <a href="#cta" className="btn-secondary">Contact Us</a>
            <a href="#cta" className="btn-primary">Start Free Trial</a>
          </div>
        </div>
      </div>
    </section>
  )
}
