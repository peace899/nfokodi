# -*- coding: utf-8 -*-
# This file is part of beets.
# Copyright 2017, Sergio Soto.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.



from __future__ import absolute_import, division, print_function

import os
from beets.plugins import BeetsPlugin



class ImportLog(BeetsPlugin):
    def __init__(self):
        super(ImportLog, self).__init__()
        self.register_listener('album_imported', self.writelog)
        
    def writelog(self, lib, album):
        #album_path = os.path(album.path)
        f = open('beetsimport.txt','a+')
        f.write("%s,%s,%s" % (album.path, album.mb_albumid, album.mb_albumartistid))
        f.close

    
