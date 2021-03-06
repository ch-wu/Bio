##Fetch single copy sequences without hypothetical protein
import re
import os
import sys

def File_Name(Address,GF):
    filename = ''
    GF_n = str(GF)
    outputname = re.findall(r'mci.I\d\d_', Address)
    for temp in outputname:
        filename = temp
    filename = filename + 'GF_' + GF_n + '.fasta'
    return filename

if __name__ == '__main__':
    all_pro_address = 'PATH/all_pro.faa'
    List_Address = '/PATH/YOUR_Single_Copy_List'
    f0 = open(all_pro_address)
    fa = f0.readlines()
    f0.close()
    f1 = open(List_Address)
    fl = f1.readlines()
    f1.close()
    GF_x = 0
    for list_line in fl:
        Single_Copy_filecontent = ''
        GF_x += 1
        for seq_line in fa:
            seq_line = seq_line.strip()
            seq_line2 = seq_line[1:]
            seq_line_split = seq_line2.split(' ')

            if seq_line[0] == '>':
                list_line = list_line.strip()
                list_line_list = list_line.split(' ')
                for name in list_line_list:
                    name = name.strip()
                    if name == seq_line_split[0]:
                        ##--------- Is hypothetical true/false? ---------
                        for word in seq_line_split:
                            T_or_F = 0
                            if word == 'hypothetical':
                                T_or_F = 1
                                break
                            else:
                                continue
                    else:
                        T_or_F = 1
                    if T_or_F == 0:
                        break
            else:
                if seq_line[0] != '>' and T_or_F == 0:
                    T_or_F = 0
                else:
                    T_or_F = 1

            if T_or_F == 0:
                Single_Copy_filecontent = Single_Copy_filecontent + seq_line + '\n'


        ##------------------- Output Single Copy Sequences --------------------
        SingleCopyFileName = File_Name(List_Address,GF_x)
        SingleCopyFile = r'/OUTPUT_PATH/%s' % (SingleCopyFileName)
        with open(SingleCopyFile,'w') as fw:
            fw.write(Single_Copy_filecontent)
            
