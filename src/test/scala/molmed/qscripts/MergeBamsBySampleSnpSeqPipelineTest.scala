package molmed.qscripts

import org.testng.annotations._
import molmed.queue.SnpSeqBaseTest
import org.broadinstitute.sting.queue.pipeline._

/**
 * TODO
 * Implement cluster style testing as in AlignWithBwaSnpSeqPipelineTest
 */

class MergeBamsBySampleSnpSeqPipelineTest {

    val pathToScript = "-S src/main/scala/molmed/qscripts/MergeBamsBySample.scala"
    val snpSeqBaseTest = SnpSeqBaseTest
    var run: Boolean = false

    @BeforeClass
    @Parameters(Array("runpipeline"))
    def init(runpipeline: Boolean): Unit = {
        this.run = runpipeline
    }

    @Test
    def testMergeBamsBySample {
        val mergeBam = "exampleBAM.bam.bam"
        
        val spec = new PipelineTestSpec
        spec.jobRunners = Seq("Shell")
        spec.name = "MergeBySample"
        spec.args = Array(
            pathToScript,
            " -i " + SnpSeqBaseTest.differentRgsCohortList, 
            " --project " + "TEST",
            " -startFromScratch ").mkString
        spec.fileMD5s += mergeBam -> "eeca6021ee8389b244c4c59f96482c72"
        
        PipelineTest.executeTest(spec, run)
    }
}