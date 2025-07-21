function login()
    users = struct('admin', '1234', 'engineer', 'abcd');
    user = input('Username: ', 's');
    pass = input('Password: ', 's');
    
    if isfield(users, user) && strcmp(users.(user), pass)
        disp('Login successful.');
    else
        error('Invalid credentials.');
    end
end