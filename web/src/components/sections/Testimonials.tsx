import { useEffect, useRef, useState } from 'react'
import { Star, Quote } from 'lucide-react'

const testimonials = [
  {
    name: 'Sarah Chen',
    role: 'Product Manager',
    company: 'Google',
    image: 'SC',
    content: 'I was paying $200/month for subscriptions I forgot about. Pausely found them all in 2 minutes and helped me pause what I wasn\'t using. Saved me $1400 in the first year.',
    rating: 5,
    savings: '$1400/year'
  },
  {
    name: 'Marcus Johnson',
    role: 'Software Engineer',
    company: 'Stripe',
    image: 'MJ',
    content: 'The free perk discovery is insane. I had no idea my Chase card gave me free DashPass and my employer paid for Calm. That\'s $40/month I was wasting.',
    rating: 5,
    savings: '$480/year'
  },
  {
    name: 'Emily Rodriguez',
    role: 'Marketing Director',
    company: 'Airbnb',
    image: 'ER',
    content: 'I love that I can pause instead of cancel. I paused my gym for 3 months while traveling, kept my account and history. So much better than the hassle of canceling.',
    rating: 5,
    savings: '$150/quarter'
  },
  {
    name: 'David Kim',
    role: 'Founder',
    company: 'Tech Startup',
    image: 'DK',
    content: 'As a founder, I\'m subscribed to like 30 different SaaS tools. Pausely showed me which ones I\'m actually using vs paying for. Cut my monthly burn by $300.',
    rating: 5,
    savings: '$3600/year'
  },
  {
    name: 'Lisa Wang',
    role: 'Designer',
    company: 'Figma',
    image: 'LW',
    content: 'The UI is beautiful and the insights are actually useful. It\'s like having a financial advisor specifically for subscriptions. Worth every penny.',
    rating: 5,
    savings: '$720/year'
  },
  {
    name: 'James Miller',
    role: 'Consultant',
    company: 'McKinsey',
    image: 'JM',
    content: 'I was skeptical but tried the free version. Found 8 subscriptions I forgot about within 5 minutes. Upgraded to Pro immediately.',
    rating: 5,
    savings: '$96/month'
  }
]

export default function Testimonials() {
  const scrollRef = useRef<HTMLDivElement>(null)
  const [canScrollLeft, setCanScrollLeft] = useState(false)
  const [canScrollRight, setCanScrollRight] = useState(true)

  const checkScroll = () => {
    if (scrollRef.current) {
      const { scrollLeft, scrollWidth, clientWidth } = scrollRef.current
      setCanScrollLeft(scrollLeft > 0)
      setCanScrollRight(scrollLeft < scrollWidth - clientWidth - 10)
    }
  }

  useEffect(() => {
    checkScroll()
    const ref = scrollRef.current
    ref?.addEventListener('scroll', checkScroll)
    return () => ref?.removeEventListener('scroll', checkScroll)
  }, [])

  const scroll = (direction: 'left' | 'right') => {
    if (scrollRef.current) {
      const scrollAmount = 400
      scrollRef.current.scrollBy({
        left: direction === 'left' ? -scrollAmount : scrollAmount,
        behavior: 'smooth'
      })
    }
  }

  return (
    <section className="section-small bg-black overflow-hidden">
      <div className="container mb-12">
        <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-6">
          <div className="max-w-2xl">
            <p className="caption mb-4">Testimonials</p>
            <h2 className="headline-medium">
              Loved by{' '}
              <span className="gradient-text">thousands</span>
              {' '}of smart savers.
            </h2>
          </div>

          <div className="flex gap-3">
            <button
              onClick={() => scroll('left')}
              disabled={!canScrollLeft}
              className={`w-12 h-12 rounded-full border flex items-center justify-center transition-all ${
                canScrollLeft 
                  ? 'border-white/20 hover:bg-white/10' 
                  : 'border-white/5 opacity-30 cursor-not-allowed'
              }`}
            >
              ←
            </button>
            <button
              onClick={() => scroll('right')}
              disabled={!canScrollRight}
              className={`w-12 h-12 rounded-full border flex items-center justify-center transition-all ${
                canScrollRight 
                  ? 'border-white/20 hover:bg-white/10' 
                  : 'border-white/5 opacity-30 cursor-not-allowed'
              }`}
            >
              →
            </button>
          </div>
        </div>
      </div>

      {/* Testimonials Carousel */}
      <div
        ref={scrollRef}
        className="flex gap-6 overflow-x-auto scrollbar-hide px-6 md:px-12 pb-4"
        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
      >
        {testimonials.map((testimonial, index) => (
          <div
            key={index}
            className="flex-shrink-0 w-[360px] bg-[#1c1c1e] rounded-3xl p-8 border border-white/5 hover:border-white/10 transition-all"
          >
            {/* Quote Icon */}
            <div className="mb-6">
              <Quote className="w-10 h-10 text-blue-500/30" />
            </div>

            {/* Content */}
            <p className="text-white/80 text-lg leading-relaxed mb-8">
              "{testimonial.content}"
            </p>

            {/* Rating */}
            <div className="flex gap-1 mb-6">
              {Array.from({ length: testimonial.rating }).map((_, i) => (
                <Star key={i} className="w-5 h-5 fill-yellow-400 text-yellow-400" />
              ))}
            </div>

            {/* Author */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center text-white font-semibold">
                  {testimonial.image}
                </div>
                <div>
                  <p className="font-semibold">{testimonial.name}</p>
                  <p className="text-sm text-white/50">{testimonial.role} at {testimonial.company}</p>
                </div>
              </div>

              <div className="text-right">
                <p className="text-green-400 font-semibold">{testimonial.savings}</p>
                <p className="text-xs text-white/40">Saved</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Stats */}
      <div className="container mt-16">
        <div className="grid grid-4 gap-8 text-center">
          {[
            { value: '10K+', label: 'Active Users' },
            { value: '$2.4M', label: 'Total Saved' },
            { value: '4.9/5', label: 'App Store Rating' },
            { value: '98%', label: 'Retention Rate' }
          ].map((stat, index) => (
            <div key={index}>
              <p className="text-4xl font-bold gradient-text mb-2">{stat.value}</p>
              <p className="text-sm text-white/50">{stat.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
