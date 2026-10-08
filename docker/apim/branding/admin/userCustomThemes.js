/*
 * Jamii Savings brand overrides for the WSO2 API Manager Admin Portal.
 * Deployed to: repository/deployment/server/webapps/admin/site/public/conf/userCustomThemes.js
 * Navy app bar with the white logo; green as the secondary colour.
 */
const userCustomThemes = {
    light: {
        palette: {
            primary: { light: '#2A4C8A', main: '#102E62', dark: '#0A1F45', contrastText: '#FFFFFF' },
            secondary: { light: '#5BBE61', main: '#3B9B4A', dark: '#2F7F3E', contrastText: '#FFFFFF' },
            background: { default: '#F6F8FB', paper: '#FFFFFF', appBar: '#102E62', leftMenu: '#102E62', leftMenuActive: '#2F7F3E' },
        },
        custom: {
            logo: '/admin/site/public/images/custom/jamii-logo-header-white.png',
            logoHeight: 36,
            logoWidth: 89,
        },
    },
};
