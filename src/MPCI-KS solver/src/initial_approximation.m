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
%          - array Uapp, the initial estimation of the spacecraft state
%            vector control law
%          - scalar tfapp, the initial initial time of flight

function [Papp, Capp, tfapp] = initial_approximation(tau, tfapp, initial, final, basis)
    % Generate the polynomial basis
    n_init = repmat(3, [1 length(initial)/2]);
    Bapp = state_basis(n_init, tau, basis);

    % Initial estimate of control points (using the non-orthonormal boundary conditions)
    Papp = zeros(3, max(n_init)+1);  
    Capp = evaluate_state(Papp, Bapp, n_init);
end