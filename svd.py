import sys
import numpy as np


##
# UPDATE THE COLUMS USED AFTER ALL CORPS USED. CURRENTLY ON 1. NEED TO , 2, 3, 4 ... N -1
##
a = np.loadtxt("input.txt", delimiter  = ",")

# example taken from Video Tutorials - All in One
# https://www.youtube.com/watch?v=P5mlg91as1c
#a = np.array([[1, 1, 1, 0, 0],
#              [3, 3, 3, 0, 0],
#              [4, 4, 4, 0, 0],
#              [5, 5, 5, 0, 0],
#              [0, 2, 0, 4, 4],
#              [0, 0, 0, 5, 5],
#              [0, 1, 0, 2, 2]])
#
# set numpy printing options
np.set_printoptions(suppress=True)
np.set_printoptions(precision=7)

#print "--- FULL ---"
U, s, VT = np.linalg.svd(a, full_matrices=False)

#print "U:\n {}".format(U_new)
#print ("s:\n {}".format(s))
#print ("VT:\n {}".format(VT))



#SVD Matrices after Truncation (2 singular values)
#print "--- Truncated (2 singular values) ---"
U_size = U.shape; 	#remove all rows after 2
s_size = s.shape; 	#remove all rows & col after 2
VT_size = VT.shape;	#remove all col after 2

U_new = np.delete(U, np.s_[2:U_size[0]], axis=1) 


S = np.diag (np.delete(s, np.s_[2:s_size[0]], axis=0))

VT_new = np.delete(VT,np.s_[2:VT_size[1]], axis = 0)

#print U_new.shape, S.shape, VT_new.shape

X_a = np.dot(np.dot(U_new, S), VT_new)
#print ("A:\n {}".format(X_a));

np.savetxt('svd_output.txt', X_a)
##SAVES SVD'D DOC-TERM MATRIX, MISSING FIRST COL OF TERMS. LIST OF TERM COL 0 OF 'input.txt'

#print "X_a \n {}".format(X_a)
