/**
 * Jamii Savings brand theme for the WSO2 API Manager 4.4 Publisher.
 * Deployed to: webapps/publisher/site/public/conf/userThemes.js (replaces the default).
 * Same shape as the default: light(theme) returns an extension of the Material-UI theme.
 * Palette: navy #102E62, green #3B9B4A, light green #5BBE61, dark green #2F7F3E, white #FFFFFF.
 */
const userThemes = {
    light(theme) {
        return (
            {
                palette: {
                    primary: { light: '#2A4C8A', main: '#102E62', dark: '#0A1F45', contrastText: '#FFFFFF' },
                    secondary: { light: '#5BBE61', main: '#3B9B4A', dark: '#2F7F3E', contrastText: '#FFFFFF' },
                },
                custom: {
                    logo: '/site/public/images/custom/jamii-logo-header-white.png',
                    logoHeight: 36,
                    logoWidth: 89,
                },
                overrides: {
                    MuiRadio: {
                        colorSecondary: {
                            '&$checked': { color: theme.palette.primary.main },
                            '&$disabled': { color: theme.palette.action.disabled },
                        },
                    },
                    MuiAppBar: {
                        colorPrimary: { backgroundColor: '#102E62' },
                    },
                    MuiButton: {
                        containedPrimary: {
                            backgroundColor: '#3B9B4A',
                            '&:hover': { backgroundColor: '#2F7F3E' },
                        },
                    },
                },
            }
        );
    },
};
if (typeof module !== 'undefined') {
    module.exports = userThemes; // Added for tests
}
