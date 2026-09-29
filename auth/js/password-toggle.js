document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.input-icon input[type="password"]').forEach(function (input) {
        var wrapper = input.closest('.input-icon');
        if (!wrapper) return;

        wrapper.classList.add('has-toggle');

        var toggle = document.createElement('button');
        toggle.type = 'button';
        toggle.className = 'password-toggle';
        toggle.setAttribute('aria-label', 'Mostrar contraseña');
        toggle.setAttribute('aria-pressed', 'false');
        toggle.innerHTML = '<i class="fa-solid fa-eye"></i>';

        toggle.addEventListener('click', function () {
            var visible = input.type === 'text';
            input.type = visible ? 'password' : 'text';
            toggle.innerHTML = visible ? '<i class="fa-solid fa-eye"></i>' : '<i class="fa-solid fa-eye-slash"></i>';
            toggle.setAttribute('aria-pressed', String(!visible));
            toggle.setAttribute('aria-label', visible ? 'Mostrar contraseña' : 'Ocultar contraseña');
        });

        wrapper.appendChild(toggle);
    });
});
