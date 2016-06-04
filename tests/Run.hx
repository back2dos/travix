package;

using buddy.Should;

@colorize
class Run extends buddy.SingleSuite {
  public function new() {
    describe("Using travix", {
      #if (sys || nodejs)
      describe("On Sys targets and Node.js", {
        it("should compile and exit with status 0 if everything went well", {
          Sys.getCwd().should.not.be(null);
        });
      });
      #elseif flash
      describe("On Flash", {
        beforeAll({
          haxe.Log.trace = function(v, ?inf) flash.Lib.trace(v);
        });

        it("should trace when using flash.Lib.trace", {
          trace("Flash trace");
        });
        it("should exit when using flash.system.System.exit", {
          // Will be done automatically by Buddy
          true.should.be(true);
        });
      });
      #else
      describe("On other targets", {
        it("should compile only", {
          true.should.be(true);
        });        
      });
      #end
    });
  }  
}