//
//  HelperContext.swift
//  Monolingual
//
//  Created by Ingmar Stein on 10.04.15.
//
//

import Foundation

final class HelperContext : NSObject, NSFileManagerDelegate {

	var dryRun: Bool
	var doStrip: Bool
	var trash: Bool
	var uid: uid_t
	var progress: NSProgress?
	var directories: Set<String>!
	var excludes: [String]!
	var bundleBlacklist: Set<String>!
	private var fileBlacklist = Set<NSURL>()
	var fileManager = NSFileManager()

	override init() {
		dryRun = false
		doStrip = false
		trash = false
		uid = 0

		super.init()

		fileManager.delegate = self
	}

	func isExcluded(path: String) -> Bool {
		for exclude in self.excludes {
			if path.hasPrefix(exclude) {
				return true
			}
		}
		return false
	}

	func isDirectoryBlacklisted(path: NSURL) -> Bool {
		if let bundle = NSBundle(URL: path), bundleIdentifier = bundle.bundleIdentifier {
			return bundleBlacklist.contains(bundleIdentifier)
		}
		return false
	}

	func isFileBlacklisted(url: NSURL) -> Bool {
		return fileBlacklist.contains(url)
	}

	func addCodeResourcesToBlacklist(url: NSURL) {
		let codeResourcesPath = url.URLByAppendingPathComponent("_CodeSignature/CodeResources", isDirectory: false)
		if let plist = NSDictionary(contentsOfURL:codeResourcesPath) as? [NSObject:AnyObject] {
			if let files = plist["files"] as? [String:[NSObject:AnyObject]] {
				for (key, value) in files {
					if let optional = value["optional"] as? Bool where !optional {
						fileBlacklist.insert(url.URLByAppendingPathComponent(key))
					}
				}
			}
			if let files = plist["files2"] as? [String:[NSObject:AnyObject]] {
				for (key, value) in files {
					if let optional = value["optional"] as? Bool where !optional {
						fileBlacklist.insert(url.URLByAppendingPathComponent(key))
					}
				}
			}
		}
	}

	func reportProgress(url: NSURL, size:Int) {
		if let progress = progress {
			let count = progress.userInfo?[NSProgressFileCompletedCountKey] as? Int ?? 0
			progress.setUserInfoObject(count + 1, forKey:NSProgressFileCompletedCountKey)
			progress.setUserInfoObject(url, forKey:NSProgressFileURLKey)
			progress.completedUnitCount += size
		}
	}

	func remove(url: NSURL) {
		var error: NSError? = nil
		if trash {
			var dstURL: NSURL? = nil

			// try to move the file to the user's trash
			var success = false
			seteuid(self.uid)
			success = fileManager.trashItemAtURL(url, resultingItemURL:&dstURL, error:&error)
			seteuid(0)
			if !success {
				// move the file to root's trash
				success = self.fileManager.trashItemAtURL(url, resultingItemURL:&dstURL, error:&error)
			}
			if let dstURL = dstURL where success {
				// trashItemAtURL does not call any delegate methods (radar 20481813)
				if let dirEnumerator = fileManager.enumeratorAtURL(dstURL, includingPropertiesForKeys:[NSURLTotalFileAllocatedSizeKey, NSURLFileAllocatedSizeKey], options:.allZeros, errorHandler:nil) {
					for entry in dirEnumerator {
						let theURL = entry as! NSURL
						var size: AnyObject?
						if !theURL.getResourceValue(&size, forKey:NSURLTotalFileAllocatedSizeKey, error:nil) {
							theURL.getResourceValue(&size, forKey:NSURLFileAllocatedSizeKey, error:nil)
						}
						if let size = size as? Int {
							reportProgress(theURL, size:size)
						}
					}
				}
			} else if let error = error {
				NSLog("Error trashing '%s': %@", url.fileSystemRepresentation, error)
			}
		} else {
			if !self.fileManager.removeItemAtURL(url, error:&error) {
				if let error = error {
					NSLog("Error removing '%s': %s", url.fileSystemRepresentation, error)
				}
			}
		}
	}

	private func fileManager(fileManager: NSFileManager, shouldProcessItemAtURL URL:NSURL) -> Bool {
		if dryRun || isFileBlacklisted(URL) {
			return false
		}

		var size: AnyObject?
		if !URL.getResourceValue(&size, forKey:NSURLTotalFileAllocatedSizeKey, error:nil) {
			URL.getResourceValue(&size, forKey:NSURLFileAllocatedSizeKey, error:nil)
		}

		if let size = size as? Int {
			reportProgress(URL, size:size)

			NSLog("processing '%s' size=%lld", URL.fileSystemRepresentation, size)
		}

		return true
	}

	//MARK: - NSFileManagerDelegate

	func fileManager(fileManager: NSFileManager, shouldRemoveItemAtURL URL: NSURL) -> Bool {
		return self.fileManager(fileManager, shouldProcessItemAtURL:URL)
	}

	func fileManager(fileManager: NSFileManager, shouldMoveItemAtURL srcURL: NSURL, toURL dstURL: NSURL) -> Bool {
		return self.fileManager(fileManager, shouldProcessItemAtURL:srcURL)
	}

}