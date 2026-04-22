# 🚀 Pausely Mission Control

**The Revolutionary Admin Dashboard for Pausely Creators**

Real-time analytics, security monitoring, and complete control over your app's ecosystem.

![Mission Control](https://img.shields.io/badge/Mission%20Control-Live-brightgreen)
![Security](https://img.shields.io/badge/Security-Active-success)
![Realtime](https://img.shields.io/badge/Realtime-Enabled-blueviolet)

## ✨ Features

### 📊 Live Analytics
- **Real-time user tracking** - See signups as they happen
- **Revenue monitoring** - MRR, ARR, LTV calculations
- **Growth charts** - Visual user growth trends
- **Conversion rates** - Free to Pro conversion tracking

### 🔒 Active Security
- **Threat detection** - Automated brute force detection
- **IP blocking** - Auto-block suspicious IPs
- **Security log** - Real-time security event stream
- **Alert system** - Instant notifications for threats

### 👥 User Management
- **Complete user list** - Search, filter, manage users
- **Subscription tiers** - See Pro vs Free distribution
- **Activity feed** - Live user activity stream
- **Referral tracking** - Monitor referral performance

### ⚙️ System Health
- **Supabase status** - Database health monitoring
- **API metrics** - Request counts, response times
- **Error tracking** - Real-time error monitoring
- **Performance stats** - App performance metrics

## 🚀 Quick Start

### 1. Setup Supabase

Run the SQL setup in your Supabase SQL Editor:

```bash
# Copy and paste contents of supabase-setup.sql
```

### 2. Configure Admin Access

```sql
-- Set yourself as admin (replace with your email)
UPDATE profiles 
SET is_admin = TRUE 
WHERE email = 'your-email@example.com';
```

### 3. Deploy Mission Control

#### Option A: Vercel (Recommended)
```bash
cd MissionControl
npm i -g vercel
vercel --prod
```

#### Option B: Netlify
```bash
cd MissionControl
npm i -g netlify-cli
netlify deploy --prod
```

#### Option C: Static Hosting
Upload `index.html`, `app.js`, and `styles.css` to any static host.

### 4. Configure Environment

Edit `app.js` and update:
```javascript
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_KEY = 'your-service-key';
```

## 📸 Dashboard Overview

### Overview Tab
- Total users counter
- Pro subscribers
- Monthly recurring revenue
- Active threats
- Live activity feed

### Users Tab
- Complete user directory
- Search and filter
- Subscription tier badges
- Last active timestamps

### Revenue Tab
- MRR/ARR calculations
- Revenue by source
- Payment breakdown
- Lifetime value tracking

### Security Tab
- Active threats list
- Failed login attempts
- Blocked IPs
- Real-time security log

### System Tab
- Supabase status
- Database size
- API request metrics
- System events

### Referrals Tab
- Referral code count
- Conversion rates
- Top referrers
- Revenue from referrals

## 🔐 Security Features

### Automatic Threat Detection
Mission Control monitors for:
- Brute force attacks (5+ failed logins)
- Suspicious IP patterns
- Rate limit violations
- Unusual API activity

### Real-time Alerts
When threats are detected:
- Dashboard shows red alert status
- Threat appears in active threats list
- Security log shows detailed info
- Badge count updates

### Audit Trail
Every action is logged:
- Admin logins
- User modifications
- Security events
- System changes

## 📊 Analytics Deep Dive

### User Metrics
- **Total Users**: All registered users
- **Active Pro**: Currently paying subscribers
- **Free Tier**: Non-paying users
- **Conversion Rate**: % of users who upgrade

### Revenue Metrics
- **MRR**: Monthly Recurring Revenue
- **ARR**: Annual Run Rate (MRR × 12)
- **LTV**: Lifetime Value (average)
- **Revenue by Source**: App Store vs LemonSqueezy

### Engagement Metrics
- **DAU**: Daily Active Users
- **Retention**: Day 1, 7, 30 retention rates
- **Session Length**: Average time in app
- **Feature Usage**: Which features are popular

## 🔧 Customization

### Adding Custom Charts

Edit `app.js` to add new charts:

```javascript
// Example: Add a custom metric chart
new Chart(ctx, {
    type: 'line',
    data: {
        labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        datasets: [{
            label: 'Your Metric',
            data: [10, 20, 30, 40, 50],
            borderColor: '#8b5cf6'
        }]
    }
});
```

### Customizing Alerts

Modify the security monitoring section:

```javascript
// In checkForThreats() function
if (someCondition) {
    triggerSecurityAlert({
        type: 'custom_alert',
        message: 'Your custom message',
        severity: 'high'
    });
}
```

## 📱 Mobile Access

Mission Control is fully responsive and works on:
- Desktop browsers
- iPad tablets
- iPhone/mobile browsers

Simply open your deployed URL on any device!

## 🚨 Troubleshooting

### "Cannot connect to Supabase"
- Check your Supabase URL and key
- Ensure RLS policies allow admin access
- Check browser console for errors

### "Not seeing real-time updates"
- Verify Realtime is enabled in Supabase
- Check that tables are in the realtime publication
- Refresh the page

### "Security alerts not working"
- Ensure security_logs table exists
- Check that log_security_event function is created
- Verify RLS policies

## 🔮 Future Enhancements

### Planned Features
- [ ] Push notifications for critical alerts
- [ ] A/B testing dashboard
- [ ] Feature flags management
- [ ] Automated email reports
- [ ] Multi-admin support with roles
- [ ] Advanced filtering and search
- [ ] Data export (CSV, PDF)
- [ ] Custom date range analytics

## 📝 Database Schema

### Tables Created

**security_logs** - Security event tracking
```
id, event_type, level, message, user_id, ip_address, created_at
```

**activity_logs** - Audit trail
```
id, user_id, action, entity_type, entity_id, old_data, new_data, created_at
```

**daily_stats** - Daily aggregated metrics
```
id, date, total_users, new_users, pro_users, mrr, total_revenue
```

**referral_analytics** - Referral tracking
```
id, referrer_id, referred_id, code_used, converted, revenue_generated
```

## 🤝 Support

For issues or questions:
1. Check the troubleshooting section
2. Review Supabase logs
3. Open an issue in the repository

## 📄 License

Mission Control is part of Pausely and follows the same license terms.

---

**Built with ❤️ for Pausely creators**

Monitor your empire. Control your destiny. 🚀
