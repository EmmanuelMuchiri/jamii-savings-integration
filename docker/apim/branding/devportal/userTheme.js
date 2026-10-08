/*
 * Jamii Savings brand theme for the WSO2 API Manager Developer Portal.
 * Deployed to: repository/deployment/server/webapps/devportal/site/public/theme/userTheme.js
 * Merged over defaultTheme.js in the same folder; keys not set here keep their defaults.
 *
 * Brand palette
 *   Navy        #102E62  primary, headings, footer, left menu
 *   Green       #3B9B4A  secondary, buttons, accents
 *   Light green #5BBE61  highlights, hover, active states
 *   Dark green  #2F7F3E  secondary dark, pressed states
 *   White       #FFFFFF  surfaces, text on dark backgrounds
 */
const userTheme = {
    palette: {
        primary: {
            light: '#2A4C8A',
            main: '#102E62',
            dark: '#0A1F45',
            contrastText: '#FFFFFF',
        },
        secondary: {
            light: '#5BBE61',
            main: '#3B9B4A',
            dark: '#2F7F3E',
            contrastText: '#FFFFFF',
        },
        background: {
            default: '#FFFFFF',
            paper: '#FFFFFF',
        },
    },
    typography: {
        fontFamily: '"Poppins", "Open Sans", "Helvetica", "Arial", sans-serif',
    },
    custom: {
        title: {
            prefix: '',
            sufix: '| Jamii Savings Developer Portal',
        },
        appBar: {
            logo: '/site/public/images/custom/jamii-logo-header.png',
            logoHeight: 44,
            logoWidth: 109,
            background: '#FFFFFF',
            backgroundImage: '',
            searchInputBackground: '#F2F5FA',
            searchInputActiveBackground: '#FFFFFF',
            activeBackground: '#E8F5E9',
            showSearch: true,
            drawerWidth: 200,
        },
        leftMenu: {
            background: '#102E62',
            backgroundSecondary: '#0A1F45',
            leftMenuActive: '#2F7F3E',
            leftMenuActiveSubmenu: '#3B9B4A',
            width: 210,
        },
        landingPage: {
            active: true,
            carousel: {
                active: true,
                slides: [
                    {
                        src: '/site/public/images/custom/jamii-banner-1.jpg',
                        title: 'Jamii Savings <span>APIs</span>',
                        content: 'Balances, customer profiles and loan eligibility, through one secure gateway.',
                    },
                    {
                        src: '/site/public/images/custom/jamii-banner-2.jpg',
                        title: 'Build with <span>Jamii</span>',
                        content: 'Subscribe once to Jamii Retail Banking and get all three APIs. Together for a brighter tomorrow.',
                    },
                ],
            },
            listByTag: {
                active: false,
            },
            parallax: {
                active: false,
            },
            contact: {
                active: false,
            },
        },
        footer: {
            active: true,
            text: '© 2026 Jamii Savings · Together for a brighter tomorrow',
            background: '#102E62',
            color: '#FFFFFF',
            height: 50,
        },
        thumbnail: {
            backgroundColor: '#102E62',
        },
        defaultApiView: 'grid',
    },
};
