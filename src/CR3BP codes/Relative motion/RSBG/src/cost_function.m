%% Project: Shape-based optimization for low-thrust transfers %%
% Date: 31/01/22

%% Cost function %%
% Function to compute the cost function to be minimized

% Inputs: - string cost, indicating the cost function to be minimized
%         - scalar mu, the gravitational parameter of the central body 
%         - vector initial, the initial boundary conditions of the
%           trajectory 
%         - vector final, the initial boundary conditions of the
%           trajectory
%         - vector n, the vector of degrees of approximation of the state
%           variables
%         - vector tau, the vector of collocation points
%         - vector x, the degree of freedom to be optimized 
%         - cell array B, the polynomial basis to be used 
%         - string basis, the polynomial basis to be used
%         - string sampling_distribution, the sampling distribution to be used
%         - string dynamics, the dynamic parametrization to be used

% Outputs: - scalar r, the cost index to be optimized

function [r] = cost_function(cost, mu, St, initial, final, n, tau, x, B, basis, sampling_distribution, dynamics)
    % Optimization variables 
    tf = x(end-1);                                      % The final time of flight

    switch (cost)
        case 'Minimum time'
            r = tf;
            
        case 'Minimum energy'
            % Minimize the control input
            P = reshape(x(1:end-2), [length(n), max(n)+1]);     % Control points
            N = floor(x(end));                                  % The optimal number of revolutions
        
            % Boundary conditions
            P = boundary_conditions(tf, n, initial, final, N, P, B, basis);
        
            % State evolution
            C = evaluate_state(P,B,n);
        
            % Evaluate the target periodic trajectory 
            switch (St.Field)
                case 'Relative'
                    St.Trajectory = target_trajectory(sampling_distribution, tf, tau, St.Period, St.Cp);
            end
        
            % Control input
            u = acceleration_control(mu, St, C, tf, dynamics);        
        
            % Control cost
            switch (dynamics)
                case 'Sundman'
                    r = sqrt(C(1,:).^2+C(3,:).^2);                   % Radial evolution
                    a = sqrt(u(1,:).^2+u(2,:).^2+u(3,:).^2);         % Non-dimensional acceleration
                    a = a./r;                                        % Dimensional acceleration

                case 'Euler'
                    a = sqrt(u(1,:).^2+u(2,:).^2+u(3,:).^2);         % Dimensional acceleration

                otherwise
                    error('No valid dynamic formulation was selected');
            end
            
            % Cost function
            r = trapz(tau,a)/tf;
            
        case 'Minimum power'
            % Minimize the control input
            P = reshape(x(1:end-2), [length(n), max(n)+1]);     % Control points
            N = floor(x(end));                                  % The optimal number of revolutions
        
            % Boundary conditions
            P = boundary_conditions(tf, n, initial, final, N, P, B, basis);
        
            % State evolution
            C = evaluate_state(P,B,n);
        
            % Evaluate the target periodic trajectory 
            switch (St.Field)
                case 'Relative'
                    St.Trajectory = target_trajectory(sampling_distribution, tf, tau, St.Period, St.Cp);
            end
        
            % Control input
            u = acceleration_control(mu, St, C, tf, dynamics);        
        
            % Control cost
            switch (dynamics)
                case 'Sundman'
                    r = sqrt(C(1,:).^2+C(3,:).^2);                   % Radial evolution
                    a = sqrt(u(1,:).^2+u(2,:).^2+u(3,:).^2);         % Non-dimensional acceleration
                    a = a./r;                                        % Dimensional acceleration

                case 'Euler'
                    a = sqrt(u(1,:).^2+u(2,:).^2+u(3,:).^2);         % Dimensional acceleration

                otherwise
                    error('No valid dynamic formulation was selected');
            end
            
            % Cost function
            r = trapz(tau,a)/tf;

        otherwise 
            error('No valid cost function was selected');
    end
end