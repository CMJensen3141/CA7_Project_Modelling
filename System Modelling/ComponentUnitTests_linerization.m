clear all
% close all

g = 9.82; % Gravitational acceleration
h0 = 0; % Height of the reference node
rho = 1000; % Density of water (kg/L)
v = 1.012*10^-6; % Kinematic viscosity of water
q_mean = 1.5/3600; % Mean assumed flow per second (1.5 cubic meters / hr)

kf = 1.8;

PipeIndex = [2 3 5 6 7 8 9 10 12 13];

PumpIndex = [1 14];

ValveIndex = [4 11];

PipeLen = [5 15 15 15 5 15 5 15 20 5]'; 
PipeDiam = 10^-3.*[25 25 25 25 25 15 25 25 15 15]';

eta = 5*10^-5.*ones(10,1); % Pipe roughness factors


% Pump coefficients
a2 = -[0.0355 0.0355]';
a1 = [0.0004 0.0004]';
a0 = [0.0001 0.0001]';


Kv = ones(1,2);


for ii = 1:length(PipeLen)
Pipes(ii) =  PipeComponent(PipeLen(ii),rho,PipeDiam(ii),g,eta(ii),q_mean,v,kf);
end

for ii = 1:length(a2)
Pumps(ii) = PumpComponent(a0(ii),a1(ii),a2(ii));
end

for ii = 1:length(Kv)
Valves(ii) = ValveComponent('Linear',Kv(ii));
end

for ii = 1:length(PipeIndex)
    Components{PipeIndex(ii)} = @(q,w,OD) Pipes(ii).Lambda(q)+Pipes(ii).mu(q,OD)+Pipes(ii).alpha(q,w);
    Inertias(PipeIndex(ii)) = Pipes(ii).J;
end

for ii = 1:length(PumpIndex)
    Components{PumpIndex(ii)} = @(q,w,OD) Pumps(ii).Lambda(q)+Pumps(ii).mu(q,OD)+Pumps(ii).alpha(q,w);
    Inertias(PumpIndex(ii)) = Pumps(ii).J;
end

for ii = 1:length(ValveIndex)
    Components{ValveIndex(ii)} = @(q,w,OD) Valves(ii).Lambda(q)+Valves(ii).mu(q,OD)+Valves(ii).alpha(q,w);
    Inertias(ValveIndex(ii)) = Valves(ii).J;
end

Inertias = diag(Inertias);



% H = [1 0 1 0 0 0 0;
%     -1 1 0 0 0 0 0;
%     0 0 -1 1 1 0 0;
%     0 -1 0 -1 0 1 0;
%     0 0 0 0 -1 0 -1;
%     0 0 0 0 0 -1 1];

 
H = [1	0	0	0	0	0	0	0	0	0	0	0	0	0;
-1	1	0	0	0	0	0	0	0	0	0	0	0	0;
0	-1	1	0	1	0	0	0	0	0	0	0	0	0;
0	0	-1	1	0	1	0	0	0	0	0	0	0	0;
0	0	0	-1	0	0	0	0	0	0	0	0	0	0;
0	0	0	0	-1	0	1	1	0	0	0	0	0	0;
0	0	0	0	0	-1	-1	0	1	0	0	0	0	0;
0	0	0	0	0	0	0	0	-1	1	0	0	0	0;
0	0	0	0	0	0	0	0	0	0	-1	0	0	0;
0	0	0	0	0	0	0	-1	0	0	1	-1	0	0;
0	0	0	0	0	0	0	0	0	-1	0	1	-1	0;
0	0	0	0	0	0	0	0	0	0	0	0	1	-1;
0	0	0	0	0	0	0	0	0	0	0	0	0	1]


 
% NodeHeights = zeros(size(H,1)-1,1)-h0;
NodeHeights = [0; 0; 0; 0; 0.9; 0; 0; 3; 0.9; 0; 0; 0]-h0; 
p0 = 0;
 
 
fooGraph = GraphModel(H,[3,7],13,[1 13],[5 9],8);

% We need to know where pumps and valves are on the FULL graph before any
% reductions
PumpEdges = [1;14];
ValveEdges = [4;11];

fooSim = HydraulicNetworkSimulation(fooGraph,Components,PumpEdges,ValveEdges,Inertias,NodeHeights,p0,rho,g);
%%

 % Collect the pressure equations in one vector
                Omegas = sym(zeros(max(fooGraph.edges),1));
                
                for ii = 1:length(fooGraph.spanT)
                    Omegas(fooGraph.spanT(ii)) = fooSim.Omega_T(ii);
                end
                for ii = 1:length(fooGraph.chords)
                    Omegas(fooGraph.chords(ii)) = fooSim.Omega_C(ii);
                end

                syms w1 w2 OD1 OD2 
                w = 66; OD = 0.5;
                %dtank = 0;
                
Omegas = subs(Omegas,[w1 w2],[w w]);
Omegas = subs(Omegas,[OD1 OD2],[OD OD]);
%Omegas = subs(Omegas,d8,dtank);
pt = 4*rho*g/10^5;
% pt = -0.25;
ResistancePart = fooGraph.Phi*Omegas;
HeightPart = (fooSim.Graph.Psi*(fooSim.NodeHeights))*(fooSim.rho*fooSim.g)/(10^5);
PressurePart = (fooSim.Graph.I*(pt-0));

dqdt = fooSim.P*(-ResistancePart+HeightPart+PressurePart);

eqpoint = solve(dqdt == 0)
struct2array(eqpoint)
%%

ts = 0.00001;


t = 0:ts:(6*60)/100; % Time vector corresponding to 6 min

clear flow tankpres df d_t pt w1 w2 OD1 OD2 pressures

w1 = 66*ones(length(t),1); w2 = 66*ones(length(t),1);
OD1 = 0.5*ones(length(t),1); OD2 = 0.5*ones(length(t),1);

qc = [0;0];
df = [0;0;0;0]; 
pt = 4*rho*g/10^5; % 4 bar normalt i boliger
d_t = 0;

for ii = 1:length(t)
    [dqdt,pbar,pt_new] = fooSim.Model_TimeStep([w1(ii) w2(ii)],[OD1(ii) OD2(ii)],[qc(1) qc(2)],[df(1) df(2) df(3) df(4)],d_t,pt);
    qc(1) = qc(1)+dqdt(1)*ts;
    qc(2) = qc(2)+dqdt(2)*ts;
    df(1) = df(1)+dqdt(3)*ts; 
    df(2) = df(2)+dqdt(4)*ts; 
    df(3) = df(3)+dqdt(5)*ts; 
    d_t = d_t+dqdt(end)*ts;

    % Must obey basic mass conservation if no leaks are assumed
    masscon = -cumsum([df(1:3);d_t]);
    df(4) = masscon(end);

    pt = pt_new;
    flow(:,ii) = [qc;df;d_t];
    pressures(:,ii) = double(pbar);
    tankpres(ii) = pt;
end

%%
% 
% W0 = [66;0;0;0;0;0;0;0;0;0;0;0;0;66];
% a0_array = [a0(1);0;0;0;0;0;0;0;0;0;0;0;0;a0(2)];
% a1_array = [a1(1);0;0;0;0;0;0;0;0;0;0;0;0;a1(2)];
% a2_array = [a2(1);0;0;0;0;0;0;0;0;0;0;0;0;a2(2)];
% 
% syms d1 d5 d8 d9 q3 q7
% % NB!!! tilføj cords!
% q_0_no_chords = subs(fooSim.q_T,[d1 d5 d8 d9 q3 q7],[eqpoint.d1 eqpoint.d5 eqpoint.d8 eqpoint.d9 eqpoint.q3 eqpoint.q7]);
% q_0 = [q_0_no_chords(1:2);eqpoint.q3;q_0_no_chords(3:6);eqpoint.q7;q_0_no_chords(7:12)];
% OD0 =[0;0;0;0.5;0;0;0;0;0;0;0.5;0;0;0];
% 
% for i = 1:length(Pipes)
%     K_lampda_only_pipes(i) = ((Pipes(i).hm+Pipes(i).hf)*Pipes(i).rho)/(10^5*3600^2);
% end
% 
% K_lampda = [0,K_lampda_only_pipes(1:2),0,K_lampda_only_pipes(3:8),0,K_lampda_only_pipes(9:10),0];
% Kv_array = [zeros(1,3),1,zeros(1,6),1,zeros(1,3)];
% 
% 
% %dd_pipes = a1_array.*W0+(abs(q_0)+sign(q_0).*q_0)*(K_lampda'+a2_array+1./(Kv_array'.*OD0).^2)
% %dd_pipes = (a1_array(2)*W0(1)+(abs(q_0(2))+sign(q_0(2)).*q_0(2))*(K_lampda(2)+a2_array(2)+1/(Kv_array(2)*OD0(2)).^2))
% % dd_pump = a1*q0+2*a0*W0

%%
close all

figure()
subplot(2,2,1)
plot(t,flow(1:2,:))
legend('Chord 1','Chord 2')
subplot(2,2,2)
plot(t,flow(3,:))
hold on
plot(t,flow(6,:))
hold off
legend('Pump 1','Pump 2')
subplot(2,2,3)
plot(t,flow(4:5,:))
legend('Consumer 1','Consumer 2')
subplot(2,2,4)
plot(t,flow(end,:))
legend('Tank')

figure()
plot(t,pressures)

figure()
subplot(3,1,1)
plot(t,tankpres)
legend('Tank Pressure')
subplot(3,1,2)
plot(t,OD1)
hold on
plot(t,OD2)
hold off
legend('Valve 1','Valve 2')
subplot(3,1,3)
plot(t,w1)
hold on
plot(t,w2)
hold off
legend('Pump 1','Pump 2')

