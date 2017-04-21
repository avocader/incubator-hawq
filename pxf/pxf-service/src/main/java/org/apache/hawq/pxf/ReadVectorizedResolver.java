package org.apache.hawq.pxf;

import java.util.List;

import org.apache.hawq.pxf.api.OneRow;
import org.apache.hawq.pxf.api.OneField;

public interface ReadVectorizedResolver {

    public List<List<OneField>> getFieldsForBatch(OneRow batch);

}
