function [matchingError, Maximum_Error]=audiogram_matching(BW,BW_val,fixedBW,shift1,gain,hh,x2,y2,audiogram_type)

bbs_selected=[];
for r=1:length(BW)
   for p=1:length(BW_val)
      if (BW_val(p)==BW(r))
          bbs_selected=[bbs_selected p];
      end
   end
end
len = length(BW);
rf=2*fixedBW./BW_val;

ln = 1024;
x=[1 zeros(1,ln)];
figure('Color','w');
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', 'Times New Roman', 'FontSize', 10, 'LineWidth', 0.75);
for i = 1:len
    temp   = VariableSRC_Farrow_8_sub(x,hh,rf(bbs_selected(i)),shift1(i),ln);
    y(i,:) = temp(1:ln);
    y4     = temp(1:ln);
    [gh,w] = freqz(y4,1,1024);
    fy3    = (gain(i)+ 20*log10(abs(gh')));
     [a,b] = size(fy3);
     ff(i,1:b)= fy3;
    plot(w/pi/2,gain(i)+20*log10(abs(gh')),'LineWidth',1.0)
    xlabel('Normalized frequency','fontsize',10,'fontweight','normal','Color','k')
    ylabel('Magnitude (dB)','fontsize',10,'fontweight','normal','Color','k')
    title('CVBW Filter Bands','fontsize',10,'fontweight','normal','Color','k')
    hold on;
    axis([0 .5 0 100]); 
end

% fig(3) 
%[x2,y2,audiogram_type]=get_audiogram(1);
plot(x2,y2,'k','LineWidth',1.2);
%axis([0 .5 0 100]);
 hold on; 
%fig(33);
sss=0;
for kk=1:length(BW)
    sss=sss+10.^(ff(kk,:)/20);
   % plot(w/2/pi,ff(kk,:));hold on
end
p1=plot(w/2/pi,mag2db(sss),'--m','LineWidth',1.2);
axis([0 .5 -10 100]); 

y3 = interp1(x2,y2,w/2/pi);
p2=plot(w/2/pi,y3,'k','LineWidth',1.2);

legend([p2 p1],{'Audiogram','Matching curve'},'TextColor','k','Color','w');
%legend('Original','Matching')
figure('Color','w');
plot(w/2/pi,y3'-mag2db(sss),'b','LineWidth',1.2); 
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', 'Times New Roman', 'FontSize', 10, 'LineWidth', 0.75);
xlabel('Normalized frequency','fontsize',10,'fontweight','normal','Color','k')
ylabel('Magnitude (dB)','fontsize',10,'fontweight','normal','Color','k')
title(sprintf('Audiogram Matching Error:%s', audiogram_type), ...
    'fontsize',10,'fontweight','normal','Color','k')
matchingError = y3'-mag2db(sss);
final_title=strcat( audiogram_type);
Maximum_Error = [ max(matchingError) min(matchingError)];
