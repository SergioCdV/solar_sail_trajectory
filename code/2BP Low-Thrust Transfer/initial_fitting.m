%% Project: 
% Date: 01/02/22

%% Initial fitting %%
% Function to estimate the trajectory approximation

% Inputs: - scalar n, the degree of the approximation 
%         - vector tau, the control parameter vector 
%         - C, the initial trajectory estimation
%         - string basis, the Bernstein polynomial basis to be used

% Outputs: - array B, the Bernstein polynomials basis in use as a cell
%          - array P, the estimation of the boundary control points as a
%            cell
%          - array C, the initial estimation of the spacecraft state vector

function [B, P, C] = initial_fitting(n, tau, C, basis)
    % The Bernstein-basis polinomials for the increasd order are calculated
    B = cell(length(n),1);      % Preallocation of the Bernstein basis
    P = zeros(3,max(n)+1);      % Preallocation of the control points

    for i = 1:length(n)
        switch (basis)
            case 'Bernstein'
                B{i} = [bernstein_basis(n(i),tau) bernstein_derivative(n(i),tau,1)];
            case 'Orthogonal Bernstein'
                B{i} = [OB_basis(n(i),tau) OB_derivative(n(i),tau,1)];
            otherwise
                error('No valid collocation polynomial basis has been selected');
        end
    end

    % Compute the position control points leveraging the complete state vector
    C = [C(1:4,:) C(5:8,:)];
    for i = 1:length(n)
        P(i,1:n(i)+1) = C(i,:)*pinv(B{i});
    end

    % Reshape the Bernstein basis
    for i = 1:length(n)
        switch (basis)
            case 'Bernstein'
                B{i} = [bernstein_basis(n(i),tau); bernstein_derivative(n(i),tau,1)];
            case 'Orthogonal Bernstein'
                B{i} = [OB_basis(n(i),tau); OB_derivative(n(i),tau,1)];
            otherwise
                error('No valid collocation polynomial basis has been selected');
        end
    end
    
    % Evaluate the state vector
    C = evaluate_state(P, B, n);
end