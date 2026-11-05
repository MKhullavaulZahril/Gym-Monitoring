from PIL import Image
import numpy as np

img = Image.open(r'd:\laragon\www\gym_monitor\assets\kartu\Depan.png').convert('RGB')
w, h = img.size
arr = np.array(img)
# sample a gold pixel of ID
x, y = int(w * 0.12), int(h * 0.756)
print('id gold pixel', arr[y, x], 'around')
for dy in range(-5, 6):
    row = arr[y+dy, int(w*0.11):int(w*0.20)]
    # brightest
    i = np.argmax(row[:,0])
    print(dy, row[i])
