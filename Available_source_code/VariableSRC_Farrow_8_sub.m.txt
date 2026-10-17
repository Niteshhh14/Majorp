function[y] = VariableSRC_Farrow_8_sub(x,hh,rf,shift,ln)

x0 = x;
Q = Farrow_diff(4);
%Q = diff1(4)
% h0=Q(1,:)*0.67;
% h1=Q(2,:)*0.67;
% h2=Q(3,:)*0.67;
h0=Q(1,:);
h1=Q(2,:);
h2=Q(3,:);
h3=Q(4,:);
h4=Q(5,:);
g0=h0;%reshape(h0,5,2);%Converting the interpolator to 64 - polyphase filters %
g1=h1;%reshape(h1,5,2);
g2=h2;%reshape(h2,5,2);
g3=h3;
g4=h4;

incr1=1*rf;
incr2=1/rf;
m = length(x0);
n = 1:m;
x0 = x0.*exp(2*pi*shift*n*1j);
 

reg1=zeros(1,length(g0));
accum1=1;
mm=1;
nn=1;
flg1=1;
%y0_sv=zeros(1,4000);
%y1_sv=zeros(1,4000);
y2_sv=zeros(1,ln);
while nn<length(x0);
    if flg1==1;
    reg1=[x0(nn) reg1(1:end-1)];
    nn=nn+1;
    flg1=0;
    end
    if accum1<2
    pntr1=floor(accum1);
    del1=accum1-pntr1;
    y0=reg1*g0(pntr1,:)';
    y1=reg1*g1(pntr1,:)';
    y2=reg1*g2(pntr1,:)';
    y3=reg1*g3(pntr1,:)';
    y4=reg1*g4(pntr1,:)';
    %y3=reg1*g3(pntr1,:)';
    %y0_sv(mm)=y0;
    %y1_sv(mm)=y0+del1*y1;
    %y2_sv(mm)=y0+del1*(y1+del1*y2/2);
    %y3_sv(mm)=y0+del1*(y1+del1*(y2/2+del1*y3/6));
    y3_sv(mm)=y0+del1*(y1+del1*(y2/2+del1*(y3/6+del1*y4/24)));
    %y3_sv(mm)=y0+del1*(y1+del1*y2/2);
    mm=mm+1;
    
    accum1=accum1+incr1;
    else
    if accum1>=2;
        accum1=accum1-1;
        flg1=1;
    end
    end
end
yx=filter(hh,1,y3_sv);
%y3=filter(hh,1,y2_sv);
reg1=zeros(1,length(g0));
accum1=1;
mm=1;
nn=1;
flg1=1;
%y0_sv=zeros(1,4000);
%y1_sv=zeros(1,4000);
y5=zeros(1,ln);
while nn<length(yx);
    if flg1==1;
    reg1=[yx(nn) reg1(1:end-1)];
    nn=nn+1;
    flg1=0;
    end
    if accum1<2
    pntr1=floor(accum1);
    del1=accum1-pntr1;
    y0=reg1*g0(pntr1,:)';
    y1=reg1*g1(pntr1,:)';
    y2=reg1*g2(pntr1,:)';
    y3=reg1*g3(pntr1,:)';
    y4=reg1*g4(pntr1,:)';
    %y0_sv(mm)=y0;
    %y1_sv(mm)=y0+del1*y1;
   % y5(mm)=y0+del1*(y1+del1*(y2/2+del1*y3/6));
    y5(mm)=y0+del1*(y1+del1*(y2/2+del1*(y3/6+del1*y4/24)));
    % y5(mm)=y0+del1*(y1+del1*y2/2);
    mm=mm+1;
    
    accum1=accum1+incr2;
    else
    if accum1>=2;
        accum1=accum1-1;
        flg1=1;
    end
    end
end    
 m = length(y5);
 n = 1:m;
 y5 = y5.*exp(2*pi*shift*n*1i);
 y  = y5;
