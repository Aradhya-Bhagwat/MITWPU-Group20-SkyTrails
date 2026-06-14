document.addEventListener('DOMContentLoaded', () => {
    // 1. Initialize Lucide Icons
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }

    // 2. Sticky Header Navigation
    const header = document.getElementById('site-header');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
    });

    // 3. Mobile Menu Toggle
    const menuToggle = document.getElementById('mobile-menu-toggle');
    const navLinks = document.getElementById('navigation-links');
    
    menuToggle.addEventListener('click', () => {
        menuToggle.classList.toggle('open');
        navLinks.classList.toggle('open');
    });

    // Close mobile menu when a link is clicked
    navLinks.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', () => {
            menuToggle.classList.remove('open');
            navLinks.classList.remove('open');
        });
    });

    // 4. FAQ Accordion Handler
    const faqItems = document.querySelectorAll('.faq-item');
    faqItems.forEach(item => {
        const btn = item.querySelector('.faq-question-btn');
        const panel = item.querySelector('.faq-answer-panel');
        
        btn.addEventListener('click', () => {
            const isActive = item.classList.contains('active');
            
            // Close all other accordions
            faqItems.forEach(otherItem => {
                if (otherItem !== item) {
                    otherItem.classList.remove('active');
                    const otherBtn = otherItem.querySelector('.faq-question-btn');
                    const otherPanel = otherItem.querySelector('.faq-answer-panel');
                    if (otherBtn) otherBtn.setAttribute('aria-expanded', 'false');
                    if (otherPanel) otherPanel.style.maxHeight = null;
                }
            });

            // Toggle active accordion
            item.classList.toggle('active');
            btn.setAttribute('aria-expanded', !isActive);
            
            if (item.classList.contains('active')) {
                panel.style.maxHeight = panel.scrollHeight + "px";
            } else {
                panel.style.maxHeight = null;
            }
        });
    });

    // 5. Toast Notifications Utility
    function showToast(message, type = 'success') {
        const toastContainer = document.getElementById('global-toast-container');
        if (!toastContainer) return;
        
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        
        const iconName = type === 'success' ? 'check-circle' : 'alert-circle';
        toast.innerHTML = `
            <i data-lucide="${iconName}"></i>
            <span>${message}</span>
        `;
        
        toastContainer.appendChild(toast);
        
        // Init icon
        if (typeof lucide !== 'undefined') {
            lucide.createIcons({
                attrs: { class: 'toast-icon' },
                nameAttr: 'data-lucide'
            });
        }
        
        // Auto-remove toast after 4 seconds
        setTimeout(() => {
            toast.style.animation = 'slide-in-toast 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275) reverse forwards';
            setTimeout(() => {
                toast.remove();
            }, 300);
        }, 4000);
    }

    // 6. Reachout Support Form Persistence & Flow
    const supportForm = document.getElementById('help-support-form');
    const successOverlay = document.getElementById('form-success-view');
    const btnResetForm = document.getElementById('btn-reset-form');

    if (supportForm) {
        supportForm.addEventListener('submit', () => {
            // We allow browser to handle mailto:
            // Show success overlay after a delay
            setTimeout(() => {
                successOverlay.style.display = 'flex';
                showToast("Opening your email client...");
            }, 500);
        });
    }

    btnResetForm.addEventListener('click', () => {
        // Reset inputs and fields
        supportForm.reset();
        successOverlay.style.display = 'none';
    });

    function validateEmail(email) {
        const re = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
        return re.test(String(email).toLowerCase());
    }

    // 8. Download CTA Alerts / Click simulations
    const downloadCTAs = [
        document.getElementById('header-btn-download'),
        document.getElementById('hero-cta-testflight')
    ];

    downloadCTAs.forEach(btn => {
        if (btn) {
            btn.addEventListener('click', () => {
                showToast("Redirecting to TestFlight...", "success");
            });
        }
    });

    // 9. Intersection Observer scroll-triggered animations
    const animatedElements = document.querySelectorAll('.feature-card, .team-card, .showcase-item, .contact-form-card');
    
    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
                revealObserver.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    });

    animatedElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        el.style.transition = 'opacity 0.6s ease-out, transform 0.6s cubic-bezier(0.2, 0.8, 0.2, 1)';
        revealObserver.observe(el);
    });
});
