function showSection(sectionId) {
    // Hide all sections
    document.getElementById('home').classList.add('hidden-section');
    document.getElementById('home').classList.remove('active-section');
    
    document.getElementById('software').classList.add('hidden-section');
    document.getElementById('software').classList.remove('active-section');
    
    document.getElementById('contact').classList.add('hidden-section');
    document.getElementById('contact').classList.remove('active-section');

    // Show the clicked section
    document.getElementById(sectionId).classList.remove('hidden-section');
    document.getElementById(sectionId).classList.add('active-section');

    // Update active state in navigation
    document.getElementById('nav-home').classList.remove('active');
    document.getElementById('nav-software').classList.remove('active');
    document.getElementById('nav-contact').classList.remove('active');

    document.getElementById('nav-' + sectionId).classList.add('active');
}