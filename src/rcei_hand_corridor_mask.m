function keep = rcei_hand_corridor_mask(annotationFile, H, W, radii, border)
%RCEI_HAND_CORRIDOR_MASK Image mask that excludes the tracked hand corridor.
%
%   keep = rcei_hand_corridor_mask(annotationFile, H, W, radii, border)
%
%   The corridor is the union of ellipses (semi-axes radii = [rx ry] px)
%   centred on the manually annotated palm positions. A border of 'border'
%   pixels is also excluded. keep(y, x) is true for pixels outside both.
%   Settings used in the paper: radii = [82 86], border = 20.

A = dlmread(annotationFile, ',', 1, 0);   % frame, time_s, palm_x_px, palm_y_px
px = A(:, 3);
py = A(:, 4);

[xx, yy] = meshgrid(1:W, 1:H);
corridor = false(H, W);
for k = 1:numel(px)
    corridor = corridor | ((xx - px(k))/radii(1)).^2 + ((yy - py(k))/radii(2)).^2 <= 1;
end
keep = ~corridor;
keep(1:border, :) = false;
keep(end-border+1:end, :) = false;
keep(:, 1:border) = false;
keep(:, end-border+1:end) = false;
end
