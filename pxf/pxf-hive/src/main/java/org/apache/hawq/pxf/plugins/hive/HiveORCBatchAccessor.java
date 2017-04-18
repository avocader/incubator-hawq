package org.apache.hawq.pxf.plugins.hive;

/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

import java.io.IOException;
import org.apache.hadoop.fs.Path;
import org.apache.hawq.pxf.api.OneRow;
import org.apache.hawq.pxf.api.utilities.InputData;
import org.apache.hadoop.hive.ql.exec.vector.VectorizedRowBatch;
import org.apache.hadoop.hive.ql.io.orc.OrcFile;
import org.apache.hadoop.hive.ql.io.orc.Reader;
import org.apache.hadoop.hive.ql.io.orc.RecordReader;
import org.apache.hadoop.io.LongWritable;

public class HiveORCBatchAccessor extends HiveAccessor {

    protected RecordReader vrr;
    private int batchIndex;

    public HiveORCBatchAccessor(InputData input) throws Exception {
        super(input);
    }

    @Override
    protected boolean getNextSplit() throws IOException {
        Reader reader = OrcFile.createReader(
                new Path(inputData.getDataSource()),
                OrcFile.readerOptions(jobConf));
        vrr = reader.rows();
        return vrr.hasNext();
    }

    @Override
    public OneRow readNextObject() throws IOException {
        data = vrr.nextBatch((VectorizedRowBatch) data);
        batchIndex++;
        if (data == null) {
            if (getNextSplit()) {
                data = vrr.nextBatch((VectorizedRowBatch) data);
                batchIndex++;
                if (data == null) {
                    return null;
                }
            } else {
                return null;
            }
        }
        key = new LongWritable(batchIndex);
        return new OneRow(key, (VectorizedRowBatch) data);
    }
}
