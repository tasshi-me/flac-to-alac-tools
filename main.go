package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/urfave/cli/v2"
)

type convertMap struct {
	src string
	dst string
}

func main() {
	fmt.Println("FLAC to ALAC tool Copyright (c) 2020 tasshi")
	fmt.Println()

	var isInteractive bool
	var withoutConfirmation bool
	var forceOverwrite bool
	var dstDir string
	var srcDir string

	flags := []cli.Flag{
		&cli.BoolFlag{
			Name:        "interactive",
			Aliases:     []string{"i"},
			Usage:       "Enable interactive mode",
			Destination: &isInteractive,
		},
		&cli.BoolFlag{
			Name:        "yes",
			Aliases:     []string{"y"},
			Usage:       "Start converting without confirmation",
			Destination: &withoutConfirmation,
		},
		&cli.BoolFlag{
			Name:        "force",
			Aliases:     []string{"f"},
			Usage:       "Attempt to overwrite output files",
			Destination: &forceOverwrite,
		},
	}

	actions := func(c *cli.Context) error {

		checkDependencies()

		srcDir = c.Args().Get(0)
		dstDir = c.Args().Get(1)
		scanner := bufio.NewScanner(os.Stdin)

		if isInteractive {
			fmt.Println("interactive mode: on")
			fmt.Println()
		}

		// src dir
		if isInteractive {
			fmt.Println("Input source directory (empty to exit).")
			fmt.Print("src dir: ")
			if scanner.Scan() {
				srcDir = scanner.Text()
			}

			if err := scanner.Err(); err != nil {
				abortWithHelp(c, "", err, 1)
			}
		}
		if len(srcDir) == 0 {
			abortWithHelp(c, "Source directory have to be specified.", nil, 1)
		}

		srcDir = strings.Replace(srcDir, "\\ ", " ", 1)

		if strings.Contains(srcDir, "~") {
			userHomeDir, err := os.UserHomeDir()
			if err != nil {
				abort("", err, 1)
			}
			srcDir = strings.Replace(srcDir, "~", userHomeDir, 1)
		}

		srcDirAbs, err := filepath.Abs(srcDir)
		if err != nil {
			abortWithHelp(c, "", err, 1)
		}
		srcDirBase := filepath.Base(srcDirAbs)

		// dst dir
		dstDirFromsrcDir := filepath.Join(filepath.Dir(srcDirAbs), "ALAC", srcDirBase)
		if isInteractive {
			fmt.Println("Input destination directory (empty to use default).")
			fmt.Println("Default: ", dstDirFromsrcDir)
			fmt.Print("dst dir: ")
			if scanner.Scan() {
				dstDir = scanner.Text()
			}

			if err := scanner.Err(); err != nil {
				abortWithHelp(c, "", err, 1)
			}
		}
		if len(dstDir) == 0 {
			dstDir = dstDirFromsrcDir
		}
		dstDirAbs, err := filepath.Abs(dstDir)
		if err != nil {
			abortWithHelp(c, "", err, 1)
		}

		// Check if src dir exists
		if exists, err := fileExists(srcDirAbs); !exists {
			abort("src dir not exists. ("+srcDirAbs+")", err, 1)
		}

		// Count FLAC files
		fmt.Println("Search FLAC files...")
		fmt.Println()
		var flacFiles []string

		err = filepath.Walk(srcDirAbs,
			func(path string, fileInfo os.FileInfo, err error) error {
				if err != nil {
					return err
				}
				if fileInfo.IsDir() {
					return nil
				}
				if filepath.Ext(path) == ".flac" {
					flacFiles = append(flacFiles, path)
				}
				return nil
			})
		if err != nil {
			abort("", err, 1)
		}

		if len(flacFiles) == 0 {
			abort("FLAC file not found in src dir.", nil, 1)
		}

		// confirmation

		fmt.Println("Convert FLAC files to ALAC")
		fmt.Println("------------------------------------------------------")
		fmt.Printf("src: %s\n", srcDirAbs)
		fmt.Printf("dst: %s\n", dstDirAbs)
		fmt.Println("------------------------------------------------------")
		fmt.Printf("After this operation, %d files will be converted.\n", len(flacFiles))
		if withoutConfirmation {
			fmt.Print("Do you want to continue? [Y/n] ")
			var confirmation string
			if scanner.Scan() {
				confirmation = scanner.Text()
			}

			if err := scanner.Err(); err != nil {
				abort("", err, 1)
			}

			if confirmation != "y" && confirmation != "Y" && confirmation != "yes" && confirmation != "YES" && confirmation != "Yes" {
				abort("", nil, 1)
			}
		}
		fmt.Println()

		// generate destination file list
		var convertMaps []convertMap
		for _, filename := range flacFiles {
			src := strings.TrimSuffix(filename, filepath.Ext(filename))
			dst := strings.Replace(src, srcDirAbs, dstDirAbs, 1)
			convertMaps = append(convertMaps, convertMap{
				src: src,
				dst: dst,
			})
		}

		// clone directory tree
		os.MkdirAll(dstDirAbs, 0755)
		if err != nil {
			abort("failed to create directory: "+dstDirAbs, err, 1)
		}
		var dirs []string
		for _, convertMap := range convertMaps {
			dirs = append(dirs, filepath.Dir(convertMap.dst))
		}

		m := make(map[string]bool)
		uniqDirs := []string{}
		for _, ele := range dirs {
			if !m[ele] {
				m[ele] = true
				uniqDirs = append(uniqDirs, ele)
			}
		}

		for _, dir := range uniqDirs {
			err = os.MkdirAll(dir, 0755)
			if err != nil {
				abort("failed to create directory: "+dir, err, 1)
			}
		}

		// convert
		for i, convertMap := range convertMaps {
			src := convertMap.src + ".flac"
			dst := convertMap.dst + ".m4a"
			icon := convertMap.dst + ".jpg"

			// Work around: ffmpeg failed to save jpg when filename contains '%'
			iconContainsPercent := strings.Contains(icon, "%")
			iconEscaped := icon
			if iconContainsPercent {
				iconEscaped = strings.ReplaceAll(icon, "%", "_percent_")
			}
			if !forceOverwrite {
				exists, err := fileExists(dst)
				if err != nil {
					abort("failed to check dst files", err, 1)
				}
				if exists {
					fmt.Printf("[%d/%d] skipped: %s\n", i+1, len(convertMaps), src)
					continue
				}
			}
			fmt.Printf("[%d/%d] %s\n", i+1, len(convertMaps), src)
			// convert to flac
			err = exec.Command("ffmpeg", "-y", "-loglevel", "panic", "-i", src, "-vn", "-acodec", "alac", dst).Run()
			if err != nil {
				log.Println(err.Error())
				abortWithDeleteOutput([]string{dst}, "failed to convert to flac", err, 1)
			}

			// export thumbnail
			err = exec.Command("ffmpeg", "-y", "-loglevel", "panic", "-i", src, iconEscaped).Run()
			// ignore errors in thumbnail
			if err != nil {
				os.Remove(iconEscaped)
				continue
				// log.Println(err.Error())
				// abortWithDeleteOutput([]string{dst, iconEscaped}, "failed to export thumbnail", err, 1)
			}
			// import thumbnail
			err = exec.Command("AtomicParsley", dst, "--artwork", iconEscaped, "--overWrite").Run()
			if err != nil {
				log.Println(err.Error())
				abortWithDeleteOutput([]string{dst, iconEscaped}, "failed to import thumbnail", err, 1)
			}
			if iconContainsPercent {
				os.Rename(iconEscaped, icon)
			}

		}

		return nil
	}

	app := &cli.App{
		Name:   "flac-to-alac",
		Usage:  "Convert flac to alac using ffmpeg and AtomicParsley",
		Flags:  flags,
		Action: actions,
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
}

func abort(message string, err error, exitCode int) {
	if len(message) > 0 {
		fmt.Println(message)
	}
	if err != nil {
		fmt.Println(err.Error())
	}
	fmt.Println("Abort.")
	fmt.Println()
	os.Exit(exitCode)
}

func abortWithHelp(c *cli.Context, message string, err error, exitCode int) {
	if len(message) > 0 {
		fmt.Println(message)
	}
	if err != nil {
		fmt.Println(err.Error())
	}
	fmt.Println("Abort.")
	fmt.Println()
	cli.ShowAppHelpAndExit(c, exitCode)
}

func abortWithDeleteOutput(outputs []string, message string, err error, exitCode int) {
	if len(message) > 0 {
		fmt.Println(message)
	}
	if err != nil {
		fmt.Println(err.Error())
	}
	if len(outputs) > 0 {
		fmt.Println("Delete broken output files...")
		for i, output := range outputs {
			fmt.Printf("[%d/%d] %s\n", i+1, len(outputs), output)
			if exists, err := fileExists(output); !exists {
				if err != nil {
					log.Fatal(err.Error())
				}
				fmt.Println("file not exists. (" + output + ")")
			} else {
				err := os.Remove(output)
				if err != nil {
					fmt.Println(err.Error())
				}
			}
		}
		fmt.Println("Done")
	}

	fmt.Println("Abort.")
	fmt.Println()
	os.Exit(exitCode)
}

func checkDependencies() {
	// check ffmpeg
	err := exec.Command("ffmpeg", "-h").Run()
	if err != nil {
		fmt.Println("Please install ffmpeg.")
		fmt.Println("Official Page: https://www.ffmpeg.org/download.html")
		fmt.Println("If you are mac user, you can install from Homebrew: brew install ffmpeg")
		fmt.Println()
		log.Fatal(err)
	}
	// check AtomicParsley
	err = exec.Command("AtomicParsley", "-h").Run()
	if err != nil {
		fmt.Println("Please install AtomicParsley.")
		fmt.Println("Official Page: https://sourceforge.net/projects/atomicparsley/files/")
		fmt.Println("If you are mac user, you can install from Homebrew: brew install AtomicParsley")
		fmt.Println()
		log.Fatal(err)
	}
}

func fileExists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}

	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}
