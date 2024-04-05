%% Project: SBOPT %%
% Date: 31/03/24

%% Close-range rendezvous in YA model %% 
% This script provides the solving of the rendezvous problem with an
% uncooperative target for demonstration purposes in ISSFD 2024

%% Set up 
close all
clear

%% Problem definition 
% Environment definition 
mu = 3.986e14;                                     % Gravitational parameter of the Earth
Re = 6378e3;                                       % Mean Earth radius
J2 = 1.08263e-3;                                   % J2 parameter of the Earth

% Mission constraints
R1 = 1e3;                                          % Keep-out zone radius 1 [m]
R2 = 10;                                           % Keep-out zone radius 2 [m]
L = 1.85;                                          % Graspling reach [m]
Fmax = 0.5e-2;                                     % Maximum available acceleration [m/s^2]
Tmax = 0.5e-2;                                     % Maximum available torque [rad/s^2]
I = diag( [1 2 3] );                               % Inertia matrix of the chaser in the body frame [kg m2]

% Mission constraints
TOF = 1 * 3600;                                    % Maximum allowed phase time [s]

% Target's initial conditions (relative position [m], velocity [m/s], LVLH MRP, LVLH angular velocity [rad/s])
ST = [7.104981874434397e6 1.137298852087994e6 -0.756578094588272e6 -0.586250624037242e3 -1.213011751682090e3 -7.268579401702199e3 zeros(1,6)].';
COE = OrbitalDynamics.ECI2COE(mu, ST, 1);

n = sqrt(mu/COE(1)^3);                             % Mean motion [rad/s]

% Initial conditions (relative position [m], velocity [m/s], LVLH MRP, LVLH angular velocity [rad/s])
sigma = zeros(1,3);
dsigma = [0 deg2rad(3.53) deg2rad(3.53)];

S0 = 1E-1 * [467.9492284850632 -77.2962065075666 -871.9827927879848 -1.7286747525940 -0.3307280703785 5.5751101965630 sigma dsigma].';  

%% Scaling 
ts = 1 / n;                     % Characteristic time 
Lc = COE(1);                    % Characteristic length
Vc = Lc / ts;                   % Characteristic velocity 
gamma = Lc / ts^2;              % Characteristic acceleration 
Tau = max(diag(I)) / ts^2;      % Characteristic torque

mu = 1;                         % Normalized gravitational parameter
n = 1;                          % Normalized time scale

Re = Re / Lc;                   % Normalized Earth's radius

TOF = TOF / ts;                 % Normalized mission time
R1 = R1 / Lc;                   % Normalized KOS radius
R2 = R2 / Lc;                   % Normalized KOS radius

L = L / Lc;                     % Normalized arm length

Fmax = Fmax / gamma;            % Normalized control acceleration 
Tmax = Tmax / Tau;              % Normalized torque 

% Normalized COE
COE([1 7])  = COE([1 7]) / Lc;  % Normalized target COE

% TH space transformation 
h = sqrt(mu * COE(1) * (1-COE(2)^2));    % Target angular momentum

% Normalized initial conditions
S0(1:3) = S0(1:3) / Lc;         % Normalized initial relative position vector
S0(4:6) = S0(4:6) / Vc;         % Normalized initial relative velocity vector
ST(1:3) = ST(1:3) / Lc;         % Normalized initial target position vector
ST(4:6) = ST(4:6) / Vc;         % Normalized initial target velocity vector

S0(10:12) = S0(10:12) * ts;     % Normalized angular velocity 
ST(10:12) = ST(10:12) * ts;     % Normalized angular velocity 

%% Final boundary conditions
% Assemble the state vector
SF = zeros(12,1);               % Final reference conditions

%% Create the problem
L = 2;                           % Degree of the dynamics (maximum derivative order of the ODE system)
StateDimension = 6;              % Dimension of the configuration vector. Note the difference with the state vector
ControlDimension = 6;            % Dimension of the control vector

% Linear problem data
params(1) = TOF;                 % TOF 

% Initial and final anomalies
[nu_0, nu_f] = wrapp_anomaly(n, COE(2), COE(6), TOF);            

params(2) = mu;                  % Gauss constant
params(3) = COE(2);              % Target orbital eccentricity
params(4) = h;                   % Angular momentum magnitude
params(5) = nu_0;                % Initial true anomaly of the target [rad]
params(6) = nu_f;                % Final true anomaly of the target [rad]
params(7) = Fmax;                % Maximum control authority (linear)
params(8) = Tmax;                % Maximum control authority (angular)

params(9:17) = reshape(I, [], 1);   % Inertia tensor of the chaser
 
% params(10) = R1;                 % Keep out sphere radius 1 [m]
% params(11) = R2;                 % Keep out sphere radius 2 [m]
% params(12) = L;                  % Graspling reach [m]

% Numerical solver definition 
basis = 'Legendre';                    % Polynomial basis to be use
time_distribution = 'Legendre';        % Distribution of time intervals
N = 10;                                % Polynomial order in the state vector expansion
m = 100;                               % Number of sampling points
 
solver = Solver(basis, N, time_distribution, m);

%% Optimization (NMPC-RTI)
% Setup
options = odeset('AbsTol', 1e-22, 'RelTol', 2.25e-14);  % Integration tolerances
Ts = 60 / ts;                                          % Sampling time

% Numerial setup
GoOn = true;                                            % Convergence boolean
iter = 1;                                               % Initial iteration
maxIter = ceil(TOF/Ts);                                 % Maximum number of iterations
elapsed_time = 0;                                       % Elapsed time

% Preallocation
St = zeros(maxIter,L * StateDimension);                 % Target trajectory
C = zeros(maxIter,L * StateDimension);                  % Relative trajectory
St(1,:) = ST.';                                         % Initial target state
C(1,:) = S0.';                                          % Initial relative state
U = [];                                                 % Control function
tc = [];                                                % Controller function time

% Noise definition
Sigma_r = (0.1 / Lc)^2 * eye(3);                        % Relative position covariance
Sigma_v = (0.5 / Vc)^2 * eye(3);                        % Relative velocity covariance

% Target and chaser ECI initial conditions
Qt = OrbitalDynamics.ECI2LVLH(St(1,1:3).', St(1,4:6).', 1);             % Rotation matrix from the ECI to the LVLH frames
y0(1:12,1) = [St(1,1:6).'; St(1,1:6).' + blkdiag(Qt.',Qt.') * S0(1:6)];  % ECI initial conditions (target - chaser)

% Nominal trajectory 
[tspan, s_ref] = ode45(@(t,s)j2_dynamics(mu, J2, Re, t, s, zeros(3,2), 0, TOF, 0, n, COE(2)), [0 TOF], y0, options);

% Transformation to the TS space
omega = mu^2 / h^3;                                              % True anomaly angular velocity
k = 1 + COE(2) * cos(nu_0);                                      % Transformation parameter
kp =  - COE(2) * sin(nu_0);                                      % Derivative of the transformation
A = [k * eye(3) zeros(3); kp * eye(3) eye(3)/(k * omega)];       % TH transformation matrix
S0(1:6) = A * S0(1:6);                                           % Initial TH relative conditions

% Preallocation of the time windows
nu_0 = [nu_0 zeros(1,maxIter-1)];
nu_f = [nu_f zeros(1,maxIter-1)];

while (GoOn && iter <= maxIter)
    % Optimization (feedback phase)
    OptProblem = ISSFD_2024.RendezvousADR(S0([1:3 7:9 4:6 10:12]), SF, L, StateDimension, ControlDimension, params);
    [S, ~, u, t0, tf, tau, exitflag, ~, P] = solver.solve(OptProblem);
    
    % Control vector
    index = sqrt(dot(u,u,1)) > Fmax;
    u(:,index) = u(:,index) / norm(u(:,index)) * Fmax;
    Pu = PolynomialBases.Legendre().modal_projection(u);

    % Preparing phase
%     solver.InitialGuessFlag = true; 
%     solver.P0 = P;
%     solver.maxIter = 10;
    
    % Plant dynamics 
    [tspan, s] = ode45(@(t,s)j2_dynamics(mu, J2, Re, t, s, Pu(1:3,:), t0, tf, Fmax, n, params(3)), [0 Ts], y0, options);  

    % Control law
    for i = 1:size(tspan,1)
        [~, nu] = wrapp_anomaly(n, params(3), t0, tspan(i));
        if (tf <= t0)
            tau = -1;
        else
            tau = 2 * (nu-t0) / (tf-t0) - 1;                                % Evaluation point for the controller
        end
        tau = min(1, max(-1, tau));
        u_aux = Pu(1:3,:) * PolynomialBases.Legendre().basis(size(Pu,2)-1, tau );

        if norm(u_aux) > Fmax
            u_aux = Fmax * u_aux / norm(u_aux); 
        end
        U = [U u_aux];
    end

    if iter == 1
        tc = tspan;
    else
        tc = [tc; tc(end) + tspan];
    end

    elapsed_time = iter * Ts;

    % Update initial conditions and state vector
    y0 = s(end,:).';                                            % New initial conditions
    St(iter+1,1:6) = s(end,1:6);                                % Target ECI state
    S0(1:6) = s(end,7:12).'-s(end,1:6).';                       % Relative state vector in the ECI frame
    C(iter+1,:) = S0;

    % Navigation system
%     noise = mvnrnd(zeros(1,6), blkdiag(Sigma_r, Sigma_v), 1).';          % Noisy state vector
%     S0 = S0 + noise;

    % Transformation to the TH LVLH frame 
    osc_COE = OrbitalDynamics.ECI2COE(mu, s(1,1:6).', 1);       % Osculating target COE
    n = sqrt(mu / osc_COE(1)^3);                                % Osculating mean motion
    h = sqrt(mu * osc_COE(1) * (1 - osc_COE(2)^2));             % Osculating angular momentum

    [nu_0(iter+1), nu_f(iter+1)] = wrapp_anomaly(n, osc_COE(2), osc_COE(6), max(0, TOF-elapsed_time));

    nu = nu_0(iter+1);                % Osculating true anomaly
    params(3) = osc_COE(2);           % Target orbital eccentricity
    params(4) = h;                    % Angular momentum magnitude
    params(5) = nu_0(iter+1);         % Initial true anomaly of the target [rad]
    params(6) = nu_f(iter+1);         % Final true anomaly of the target [rad]% Update the problem parameters

    % Rotation matrix from the ECI to the LVLH frames
    Qt = OrbitalDynamics.ECI2LVLH(St(iter+1,1:3).', St(iter+1,4:6).', 1);     

    S0(1:6) = blkdiag(Qt, Qt) * S0(1:6);                        % Initial conditions in the LVLH frame
    omega = mu^2 / h^3;                                         % True anomaly angular velocity
    k = 1 + osc_COE(2) * cos(nu);                               % Transformation parameter
    kp =  - osc_COE(2) * sin(nu);                               % Derivative of the transformation
    A = [k * eye(3) zeros(3); kp * eye(3) eye(3)/(k * omega)];  % TH transformation matrix
    S0(1:6) = A * S0(1:6);                                      % Initial conditions in the TH LVLH frame

    % Convergence 
    if (elapsed_time >= TOF)
        GoOn = false;
    else
        % Update the number of iterations
        iter = iter + 1;
    end
end

% Final processing of the results
St = St.';                   % Target trajectory
C = C.';                     % Linear relative trajectory
C = C(:,1:iter);
St = St(:,1:iter);

nu_0 = nu_0(1:iter);
nu_f = nu_f(1:iter);
 
t = Ts * (0:iter-1);         % Elapsed time vector

%% Dimensionalization
t = t * ts;                     % Mission time  
C(1:3,:) = C(1:3,:) * Lc;       % Relative position 
C(4:6,:) = C(4:6,:) * Vc;       % Relative velocity
U(1:3,:) = U(1:3,:) * gamma;    % Linear control acceleration
U(4:6,:) = U(4:6,:) * Tau;      % Angular control acceleration

%% Plots
% State representation
figure
subplot(1,2,1)
hold on
xlabel('$t$')
ylabel('$\boldmath{\rho}$ [km]', 'Interpreter','latex')
plot(t, C(1:3,:) / 1e3);
legend('$x$', '$y$', '$z$')
hold off
grid on;
xlim([0 t(end)])

subplot(1,2,2)
hold on
xlabel('$t$')
ylabel('$\dot{\boldmath{\rho}}$ [m/s]')
plot(t, C(4:6,:) );
legend('$\dot{x}$', '$\dot{y}$', '$\dot{z}$')
hold off
grid on;
xlim([0 t(end)])

% Propulsive acceleration plot
figure;
hold on
plot(tc, U(1:3,:), 'LineWidth', 0.3)
plot(tc, sqrt(dot(U(1:3,:), U(1:3,:), 1)), 'k');
yline(Fmax * gamma, 'k--')
xlabel('$\nu$')
ylabel('$\mathbf{u}$ [m/$s^2$]')
legend('$u_r$', '$u_v$', '$u_h$', '$\|\mathbf{u}\|_2$', '$u_{max}$');
grid on;
%xlim([0 t(end)])

% Propulsive acceleration plot
figure;
hold on
plot(tc, U(4:6,:), 'LineWidth', 0.3)
plot(tc, sqrt(dot(U(4:6,:), U(4:6,:), 1)), 'k');
yline(Tmax * gamma, 'k--')
xlabel('$\nu$')
ylabel('$\mathbf{\tau}$ [m/$s^2$]')
legend('$\tau_x$', '$\tau_y$', '$\tau_z$', '$\|\mathbf{\tau}\|_2$', '$\tau_{max}$');
grid on;
%xlim([0 t(end)])

figure
view(3)
hold on
xlabel('$x$ [km]')
ylabel('$y$ [km]')
zlabel('$z$ [km]')
plot3(C(1,:) / 1e3, C(2,:) / 1e3, C(3,:) / 1e3);
zticklabels(strrep(zticklabels, '-', '$-$'));
yticklabels(strrep(yticklabels, '-', '$-$'));
xticklabels(strrep(xticklabels, '-', '$-$'));
hold off
grid on;

if false
    r1 = [cos(nu_0); sin(nu_0)];
    r2 = [cos(nu_f); sin(nu_f)];
    figure 
    grid on;
    xlim([-1 1])
    ylim([-1 1])
    for i = 1:size(nu_0,2)
        hold on
        J = plot(r1(1,i), r1(2,i), 'or');
        H = plot(r2(1,i), r2(2,i), 'ob');
        drawnow;
        pause(2)
        delete(J);
        delete(H)
    end
end

%% Auxiliary functions 
% CW dynamics 
function [drho] = CW_dynamics(t,s,P,t0,tf,Fmax)

    drho(1:3,:) = s(4:6,:);
    tau = 2 * (t) / (tf-t0) - 1;                                % Evaluation point for the controller
    tau = min(1, max(-1, tau));

    B = PolynomialBases.Legendre().basis(size(P,2)-1, tau);
    u = P * B;

    if norm(u) > Fmax
        u = Fmax * u / norm(u); 
    end

    drho(4:6,:) = u + [2 * s(6,:); -s(2,:); 3 * s(3,:) - 2 * s(4,:)];

end

% Osculating J2 dynamics
function [dr] = j2_dynamics(mu, J2, Re, t, s, P, t0, tf, Fmax, n, e)
    % LVLH transformation 
    Qt = OrbitalDynamics.ECI2LVLH(s(1:3,:), s(4:6,:), 1).';

    % Common terms
    rsquare = dot(s(1:3,:), s(1:3,:), 1);
    ReJ2 = Re^2 ./ rsquare;

    % Target dynamics
    a = 1 - 1.5 * J2 * ReJ2 .* (5 * (s(3,:).^2 ./ rsquare) - 1 );
    b = 1 - 1.5 * J2 * ReJ2 .* (5 * (s(3,:).^2 ./ rsquare) - 3 );
    dr(1:3,1) = s(4:6);                                                         % Position derivative
    dr(4:6,1) = - mu * s(1:3,:) ./ sqrt( rsquare ).^3 .* [a; a; b];             % Velocity derivative

    % Chaser dynamics
    rsquare = dot(s(7:9,:), s(7:9,:), 1);
    ReJ2 = Re^2 ./ rsquare;

    a = 1 - 1.5 * J2 * ReJ2 * ( 5 * ( s(9,:).^2 ./ rsquare) - 1 );
    b = 1 - 1.5 * J2 * ReJ2 * ( 5 * ( s(9,:).^2 ./ rsquare) - 3 );

    % Controller
    [~, nu] = wrapp_anomaly(n, e, t0, t);

    if (tf <= t0)
        tau = -1;
    else
        tau = 2 * (nu-t0) / (tf-t0) - 1;                                % Evaluation point for the controller
    end
    tau = min(1, max(-1, tau));

    B = PolynomialBases.Legendre().basis(size(P,2)-1, tau);
    u = P * B;

    if norm(u) > Fmax
        u = Fmax * u / norm(u); 
    end

    dr(7:9,1) = s(10:12);                                                      % Position derivative
    dr(10:12,1) = Qt * u - mu * s(7:9,:) ./ sqrt( rsquare ).^3 .* [a; a; b];   % Velocity derivative
end

% Compute the final true anomaly considering multiple revolutions 
function [nu_0, nu_f] = wrapp_anomaly(n, e, M, t)
    % Initial true anomaly [rad]
    nu_0 = OrbitalDynamics.KeplerSolver(e, M); 

    % Final true anomaly
    T = 2*pi/ n;                         % Orbital period
    K = floor(t / T);                    % Number of complete revolutions
    dt = t - K * (2*pi/n);               % Elapsed time in the last revolution [s]
    Mf = M + n * dt;                     % Final mean anomaly [rad]
    
    % Final true anomaly [rad]
    nu_f = OrbitalDynamics.KeplerSolver(e, Mf);  
    
    dnu = nu_f - nu_0; 
    if (dnu < 0)
        dnu = 2 * pi + dnu;
    end
    
    nu_f = 2 * pi * K + nu_0 + dnu;
end