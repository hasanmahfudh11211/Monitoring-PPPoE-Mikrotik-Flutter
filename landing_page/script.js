// Mobile Menu Toggle
const menuToggle = document.querySelector('.menu-toggle');
const navLinks = document.querySelector('.nav-links');

if (menuToggle) {
    menuToggle.addEventListener('click', () => {
        navLinks.classList.toggle('active');
    });
}

// Dark Mode Toggle
const themeToggleBtn = document.getElementById('theme-toggle');
const body = document.body;
const icon = themeToggleBtn ? themeToggleBtn.querySelector('i') : null;
const heroImg = document.getElementById('hero-img');

// Function to set theme
function setTheme(theme) {
    if (theme === 'dark') {
        body.setAttribute('data-theme', 'dark');
        localStorage.setItem('theme', 'dark');
        if (icon) icon.classList.replace('fa-moon', 'fa-sun');
        if (heroImg) heroImg.src = 'assets/img/dashboard-dark.jpg';
    } else {
        body.removeAttribute('data-theme');
        localStorage.setItem('theme', 'light');
        if (icon) icon.classList.replace('fa-sun', 'fa-moon');
        if (heroImg) heroImg.src = 'assets/img/dashboard.jpg';
    }
}

// Check Local Storage for Theme on Load
const currentTheme = localStorage.getItem('theme');
if (currentTheme) {
    setTheme(currentTheme);
} else {
    // Default to light if no preference
    setTheme('light');
}

// Event Listener
if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
        const isDark = body.getAttribute('data-theme') === 'dark';
        setTheme(isDark ? 'light' : 'dark');
    });
}

// Initialize AOS
if (typeof AOS !== 'undefined') {
    AOS.init({
        once: true,
        offset: 100,
    });
}

// Initialize Swiper
if (typeof Swiper !== 'undefined' && document.querySelector('.mySwiper')) {
    var swiper = new Swiper(".mySwiper", {
        effect: "coverflow",
        grabCursor: true,
        centeredSlides: true,
        slidesPerView: "auto",
        coverflowEffect: {
            rotate: 50,
            stretch: 0,
            depth: 100,
            modifier: 1,
            slideShadows: true,
        },
        pagination: {
            el: ".swiper-pagination",
        },
        navigation: {
            nextEl: ".swiper-button-next",
            prevEl: ".swiper-button-prev",
        },
        autoplay: {
            delay: 2500,
            disableOnInteraction: false,
        },
    });
}

// FAQ Accordion
const faqItems = document.querySelectorAll('.faq-item');
if (faqItems.length > 0) {
    faqItems.forEach(item => {
        const question = item.querySelector('.faq-question');
        if (question) {
            question.addEventListener('click', () => {
                item.classList.toggle('active');
            });
        }
    });
}
