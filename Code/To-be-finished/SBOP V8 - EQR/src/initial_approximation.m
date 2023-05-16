%% Project: Shape-based optimization for low-thrust transfers %%
% Date: 31/01/22

%% Initial approximation %%
% Function to estimate the initial time of flight, control points and curve approximation

% Inputs: - dynamics, string specifying the independent variable
%           determining the dynamics of the problem
%         - vector tau, the collocation points to be used 
%         - vector initial, the initial boundary conditions of the
%           trajectory
%         - vector final, the final boundary conditions of the
%           trajectory
%         - string basis, specifying the polynomial collacation basis

% Outputs: - array Papp, the initial estimation of the boundary control
%            points
%          - array Capp, the initial estimation of the spacecraft state vector
%          - scalar thetaf, the estimated final anomaly
%          - scalar tfapp, the initial initial time of flight

function [Papp, Capp, thetaf] = initial_approximation(tau, tfapp, initial, final, basis)
    % Preliminary number of revolutions
    dtheta = final(2)-initial(2);
    if (dtheta < 0)
        dtheta = dtheta + 2*pi; 
    end
    
    Napp = ceil( (dtheta+tfapp*0.5*(initial(4)+final(4)) ) / (2*pi) );
    if (Napp <= 0)
        Napp = 1;
    end 
    
    % New initial TOF
    thetaf = final(end)+2*pi*Napp;

    % Generate the polynomial basis
    n_init = repmat(3, [1 5]);
    Bapp = state_basis(n_init, tau, basis);

    % Initial estimate of control points (using the non-orthonormal boundary conditions)
    Papp = zeros(length(n_init), max(n_init)+1);  
    Papp = boundary_conditions(n_init, initial(1:5), final(1:5), Papp, Bapp, basis);

    % State vector approximation as a function of time
    Capp = evaluate_state(Papp, Bapp, n_init);
end