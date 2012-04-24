//
// Flump - Copyright 2012 Three Rings Design

package flump.export {

import flash.filesystem.File;
import flash.utils.ByteArray;

import deng.fzip.FZip;
import deng.fzip.FZipFile;

import flump.executor.Executor;
import flump.executor.Future;
import flump.executor.VisibleFuture;
import flump.xfl.ParseError;
import flump.xfl.XflLibrary;

import com.threerings.util.F;
import com.threerings.util.Log;

public class FlaLoader
{
    public function load (name :String, file :File) :Future {
        log.info("Loading fla", "path", file.nativePath, "name", name);

        const future :VisibleFuture = new VisibleFuture();
        _library = new XflLibrary(name);
        _library.loadSWF(Files.replaceExtension(file, "swf")).completed.add(function () :void {
            // Since listLibrary shuts down the executor, wait for the swf to load first
            listLibrary(file);
        });
        _loader.terminated.add(function (..._) :void {
            _library.finishLoading();
            future.succeed(_library);
        });

        return future;
    }

    protected function listLibrary (file :File) :void {
        const loadZip :Future = Files.load(file, _loader);
        loadZip.succeeded.add(function (data :ByteArray) :void {
            const zip :FZip = new FZip();
            zip.loadBytes(data);

            const domFile :FZipFile = zip.getFileByName("DOMDocument.xml");
            const symbolPaths :Vector.<String> = _library.parseDocumentFile(
                domFile.content, domFile.filename);
            for each (var path :String in symbolPaths) {
                var symbolFile :FZipFile = zip.getFileByName(path);
                _library.parseLibraryFile(symbolFile.content, path);
            }
            _loader.shutdown();
        });
        loadZip.failed.add(function (error :Object) :void {
            _library.addTopLevelError(ParseError.CRIT, "Unable to read " + file.nativePath, error);
            _loader.shutdown();
        });
    }

    protected const _loader :Executor = new Executor();

    protected var _library :XflLibrary;

    private static const log :Log = Log.getLog(FlaLoader);
}
}
