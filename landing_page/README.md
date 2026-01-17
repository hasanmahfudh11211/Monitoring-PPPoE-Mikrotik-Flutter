# Mikrotik Monitor Landing Page

This directory contains the source code for the Mikrotik Monitor landing page.

## Structure

- `index.html`: Main landing page.
- `features.html`: Detailed features page.
- `about.html`: About Us page.
- `contact.html`: Contact page with form.
- `privacy.html`: Privacy Policy page.
- `style.css`: Main stylesheet (includes Dark Mode styles).
- `script.js`: Main JavaScript file (Mobile menu, Dark mode, Swiper, AOS, Back to Top).
- `assets/`: Contains images and other static assets.

## Features

- **Responsive Design**: Works on mobile, tablet, and desktop.
- **Dark Mode**: Toggleable dark mode with persistence (localStorage).
- **SEO Optimized**: Includes Meta tags, Open Graph, Twitter Cards, Sitemap, and Robots.txt.
- **Performance**: Lazy loading for images, preloading for critical assets.
- **Accessibility**: ARIA labels for interactive elements.

## Editing

### Changing Content

Edit the respective HTML files. Common sections like Navbar and Footer are repeated in each file and need to be updated everywhere if changed.

### Styling

All styles are in `style.css`. Use CSS variables defined in `:root` for colors and theme settings.

### Scripts

`script.js` handles all interactive functionality.

## Deployment

Upload all files in this directory to your web server's public folder. Ensure `sitemap.xml` and `robots.txt` are at the root level if this is the main site.
