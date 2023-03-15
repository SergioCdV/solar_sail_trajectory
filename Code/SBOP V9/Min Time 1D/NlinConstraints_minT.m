%% Project: Shape-based optimization for low-thrust transfers %%
% Date: 07/02/2023

%% Constraints function %% 
% Function implementation of the path and boundary constraints functions

function [c, ceq] = NlinConstraints(params, beta, t0, tf, tau, s, u)
    % Inequality constraints
    c = dot(u,u,1)-params(1)^2; 

    % Equality constraints
    ceq = [];
end