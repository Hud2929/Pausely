/**
 * Pausely Mission Control
 * Revolutionary Admin Dashboard with Real-time Analytics & Security
 */

// Supabase Configuration - REPLACE WITH YOUR CREDENTIALS
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_KEY = 'YOUR_SUPABASE_SERVICE_KEY';

// Initialize Supabase
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// Global State
let currentUser = null;
let realtimeChannels = [];
let charts = {};
let securityAlerts = [];
let activityLog = [];

// DOM Elements
const authScreen = document.getElementById('auth-screen');
const dashboard = document.getElementById('dashboard');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');

// ==================== AUTHENTICATION ====================

loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('admin-email').value;
    const password = document.getElementById('admin-password').value;
    
    try {
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password
        });
        
        if (error) throw error;
        
        // Check if user is admin
        const { data: profile } = await supabase
            .from('profiles')
            .select('is_admin')
            .eq('id', data.user.id)
            .single();
        
        if (!profile?.is_admin) {
            throw new Error('Unauthorized: Admin access only');
        }
        
        currentUser = data.user;
        showDashboard();
        initializeMissionControl();
        
    } catch (error) {
        loginError.textContent = error.message;
    }
});

document.getElementById('logout-btn').addEventListener('click', async () => {
    await supabase.auth.signOut();
    location.reload();
});

function showDashboard() {
    authScreen.classList.add('hidden');
    dashboard.classList.remove('hidden');
}

// ==================== NAVIGATION ====================

document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const section = btn.dataset.section;
        
        // Update active states
        document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
        
        btn.classList.add('active');
        document.getElementById(section).classList.add('active');
    });
});

// ==================== MISSION CONTROL INIT ====================

async function initializeMissionControl() {
    await Promise.all([
        loadOverviewStats(),
        loadUserGrowthChart(),
        loadRevenueChart(),
        setupRealtimeSubscriptions(),
        loadRecentUsers(),
        loadSecurityMetrics(),
        loadSystemStatus(),
        loadReferralStats()
    ]);
    
    // Start security monitoring
    startSecurityMonitoring();
    
    // Log admin entry
    logActivity('admin_login', 'Admin accessed Mission Control', 'security');
}

// ==================== OVERVIEW STATS ====================

async function loadOverviewStats() {
    try {
        // Total Users
        const { count: totalUsers } = await supabase
            .from('profiles')
            .select('*', { count: 'exact', head: true });
        
        document.getElementById('total-users').textContent = formatNumber(totalUsers);
        
        // Pro Users
        const { count: proUsers } = await supabase
            .from('profiles')
            .select('*', { count: 'exact', head: true })
            .eq('subscription_tier', 'pro');
        
        document.getElementById('pro-users').textContent = formatNumber(proUsers);
        
        // Free Users
        const freeUsers = totalUsers - proUsers;
        document.getElementById('free-users').textContent = formatNumber(freeUsers);
        
        // Conversion Rate
        const conversionRate = totalUsers > 0 ? ((proUsers / totalUsers) * 100).toFixed(1) : 0;
        document.getElementById('conversion-rate').textContent = `${conversionRate}% conversion`;
        
        // Today's New Users
        const today = new Date().toISOString().split('T')[0];
        const { count: todayUsers } = await supabase
            .from('profiles')
            .select('*', { count: 'exact', head: true })
            .gte('created_at', today);
        
        document.getElementById('users-change').textContent = `+${todayUsers} today`;
        
        // Calculate MRR
        const { data: subscriptions } = await supabase
            .from('user_subscriptions')
            .select('monthly_cost')
            .eq('status', 'active');
        
        const mrr = subscriptions?.reduce((sum, sub) => sum + (sub.monthly_cost || 0), 0) || 0;
        document.getElementById('pro-change').textContent = `$${mrr.toFixed(0)} MRR`;
        
    } catch (error) {
        console.error('Error loading overview stats:', error);
    }
}

// ==================== CHARTS ====================

async function loadUserGrowthChart() {
    const ctx = document.getElementById('growth-chart').getContext('2d');
    
    // Get last 7 days of user signups
    const days = [];
    const counts = [];
    
    for (let i = 6; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        days.push(date.toLocaleDateString('en-US', { weekday: 'short' }));
        
        const { count } = await supabase
            .from('profiles')
            .select('*', { count: 'exact', head: true })
            .gte('created_at', dateStr)
            .lt('created_at', dateStr + 'T23:59:59');
        
        counts.push(count);
    }
    
    charts.growth = new Chart(ctx, {
        type: 'line',
        data: {
            labels: days,
            datasets: [{
                label: 'New Users',
                data: counts,
                borderColor: '#8b5cf6',
                backgroundColor: 'rgba(139, 92, 246, 0.1)',
                fill: true,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
                y: { beginAtZero: true, grid: { color: 'rgba(255,255,255,0.1)' } },
                x: { grid: { display: false } }
            }
        }
    });
}

async function loadRevenueChart() {
    const ctx = document.getElementById('revenue-chart').getContext('2d');
    
    // Get revenue by source
    const { data: payments } = await supabase
        .from('payments')
        .select('amount, source')
        .eq('status', 'completed');
    
    const revenueBySource = {};
    payments?.forEach(payment => {
        revenueBySource[payment.source] = (revenueBySource[payment.source] || 0) + payment.amount;
    });
    
    charts.revenue = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: Object.keys(revenueBySource).map(s => s.charAt(0).toUpperCase() + s.slice(1)),
            datasets: [{
                data: Object.values(revenueBySource),
                backgroundColor: ['#8b5cf6', '#ec4899', '#f59e0b', '#10b981']
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { position: 'right', labels: { color: '#fff' } } }
        }
    });
}

// ==================== REAL-TIME SUBSCRIPTIONS ====================

function setupRealtimeSubscriptions() {
    // Subscribe to new users
    const usersChannel = supabase
        .channel('users')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'profiles' }, (payload) => {
            handleNewUser(payload.new);
        })
        .subscribe();
    
    realtimeChannels.push(usersChannel);
    
    // Subscribe to payments
    const paymentsChannel = supabase
        .channel('payments')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'payments' }, (payload) => {
            handleNewPayment(payload.new);
        })
        .subscribe();
    
    realtimeChannels.push(paymentsChannel);
    
    // Subscribe to security events
    const securityChannel = supabase
        .channel('security')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'security_logs' }, (payload) => {
            handleSecurityEvent(payload.new);
        })
        .subscribe();
    
    realtimeChannels.push(securityChannel);
}

function handleNewUser(user) {
    // Update stats
    const totalEl = document.getElementById('total-users');
    const current = parseInt(totalEl.textContent.replace(/,/g, ''));
    totalEl.textContent = formatNumber(current + 1);
    
    // Add to activity feed
    addActivityItem({
        icon: '👤',
        title: `New user signed up: ${user.email || 'Anonymous'}`,
        time: 'Just now',
        type: 'user'
    });
    
    // Update chart
    if (charts.growth) {
        const data = charts.growth.data.datasets[0].data;
        data[data.length - 1]++;
        charts.growth.update();
    }
}

function handleNewPayment(payment) {
    addActivityItem({
        icon: '💰',
        title: `Payment received: $${payment.amount} via ${payment.source}`,
        time: 'Just now',
        type: 'payment'
    });
    
    // Update revenue display
    loadOverviewStats();
}

// ==================== ACTIVITY FEED ====================

function addActivityItem(item) {
    const list = document.getElementById('activity-list');
    
    const div = document.createElement('div');
    div.className = 'activity-item';
    div.innerHTML = `
        <div class="activity-icon ${item.type}">${item.icon}</div>
        <div class="activity-content">
            <div class="activity-title">${item.title}</div>
            <div class="activity-time">${item.time}</div>
        </div>
    `;
    
    list.insertBefore(div, list.firstChild);
    
    // Keep only last 50 items
    while (list.children.length > 50) {
        list.removeChild(list.lastChild);
    }
}

async function loadRecentUsers() {
    const { data: users } = await supabase
        .from('profiles')
        .select('id, email, created_at, subscription_tier')
        .order('created_at', { ascending: false })
        .limit(5);
    
    users?.forEach(user => {
        addActivityItem({
            icon: '👤',
            title: `User ${user.email || user.id.slice(0, 8)}... joined`,
            time: timeAgo(user.created_at),
            type: 'user'
        });
    });
}

// ==================== SECURITY MONITORING ====================

function startSecurityMonitoring() {
    // Simulate security monitoring (in production, this would be real)
    setInterval(() => {
        checkForThreats();
    }, 30000); // Check every 30 seconds
}

async function checkForThreats() {
    // Check for suspicious login patterns
    const { data: failedLogins } = await supabase
        .from('security_logs')
        .select('*')
        .eq('event_type', 'failed_login')
        .gte('created_at', new Date(Date.now() - 300000).toISOString()); // Last 5 minutes
    
    if (failedLogins?.length > 5) {
        triggerSecurityAlert({
            type: 'brute_force',
            message: `Multiple failed login attempts detected (${failedLogins.length})`,
            severity: 'high'
        });
    }
}

function handleSecurityEvent(event) {
    const log = document.getElementById('security-log');
    
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.innerHTML = `
        <span class="log-time">${new Date(event.created_at).toLocaleTimeString()}</span>
        <span class="log-level ${event.level}">${event.level.toUpperCase()}</span>
        <span class="log-message">${event.message}</span>
    `;
    
    log.insertBefore(entry, log.firstChild);
    
    // Update threat count
    if (event.level === 'danger') {
        const threatCount = document.getElementById('threats-count');
        threatCount.textContent = parseInt(threatCount.textContent) + 1;
        
        // Show alert
        document.getElementById('security-status').classList.add('alert');
        document.querySelector('.status-text').textContent = 'ALERT';
    }
}

function triggerSecurityAlert(alert) {
    securityAlerts.push(alert);
    
    const threatsList = document.getElementById('active-threats');
    
    const threatDiv = document.createElement('div');
    threatDiv.className = 'threat-item';
    threatDiv.innerHTML = `
        <strong>🚨 ${alert.type.toUpperCase()}</strong>
        <p>${alert.message}</p>
        <small>${new Date().toLocaleTimeString()}</small>
    `;
    
    // Remove "no threats" message
    const noThreats = threatsList.querySelector('.no-threats');
    if (noThreats) noThreats.remove();
    
    threatsList.appendChild(threatDiv);
}

async function loadSecurityMetrics() {
    // Failed logins (24h)
    const { count: failedLogins } = await supabase
        .from('security_logs')
        .select('*', { count: 'exact', head: true })
        .eq('event_type', 'failed_login')
        .gte('created_at', new Date(Date.now() - 86400000).toISOString());
    
    document.getElementById('failed-logins').textContent = failedLogins || 0;
}

// ==================== SYSTEM STATUS ====================

async function loadSystemStatus() {
    // Database size (approximation from row counts)
    const { count: totalRows } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true });
    
    const estimatedSize = (totalRows * 2).toFixed(0); // Rough estimate
    document.getElementById('db-size').textContent = `${estimatedSize} MB`;
    
    // API requests would come from Supabase dashboard or logs
    document.getElementById('api-requests').textContent = 'Loading...';
    document.getElementById('response-time').textContent = '24ms';
}

// ==================== REFERRAL STATS ====================

async function loadReferralStats() {
    const { count: totalCodes } = await supabase
        .from('referral_codes')
        .select('*', { count: 'exact', head: true });
    
    document.getElementById('total-referral-codes').textContent = formatNumber(totalCodes);
    
    const { count: successfulReferrals } = await supabase
        .from('referral_conversions')
        .select('*', { count: 'exact', head: true });
    
    document.getElementById('successful-referrals').textContent = formatNumber(successfulReferrals);
    
    const conversionRate = totalCodes > 0 ? ((successfulReferrals / totalCodes) * 100).toFixed(1) : 0;
    document.getElementById('referral-conversion').textContent = `${conversionRate}%`;
}

// ==================== UTILITY FUNCTIONS ====================

function formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return num.toString();
}

function timeAgo(date) {
    const seconds = Math.floor((new Date() - new Date(date)) / 1000);
    
    let interval = seconds / 31536000;
    if (interval > 1) return Math.floor(interval) + ' years ago';
    
    interval = seconds / 2592000;
    if (interval > 1) return Math.floor(interval) + ' months ago';
    
    interval = seconds / 86400;
    if (interval > 1) return Math.floor(interval) + ' days ago';
    
    interval = seconds / 3600;
    if (interval > 1) return Math.floor(interval) + ' hours ago';
    
    interval = seconds / 60;
    if (interval > 1) return Math.floor(interval) + ' minutes ago';
    
    return 'Just now';
}

function logActivity(type, message, category) {
    addActivityItem({
        icon: category === 'security' ? '🔒' : 'ℹ️',
        title: message,
        time: 'Just now',
        type: category
    });
}

// ==================== INITIALIZATION ====================

// Check if already logged in
supabase.auth.getSession().then(({ data: { session } }) => {
    if (session) {
        currentUser = session.user;
        showDashboard();
        initializeMissionControl();
    }
});

// Handle visibility change (pause/resume realtime)
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        realtimeChannels.forEach(channel => channel.unsubscribe());
    } else {
        setupRealtimeSubscriptions();
    }
});
