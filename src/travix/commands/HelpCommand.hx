package travix.commands;

import Sys.*;

class HelpCommand extends Command {
  
  override function execute() {
    println('Commands');
    println('  ');
    println('  init - initializes a project with a .travis.yml');
    println('  install - installs dependencies');
    println('  interp - run tests on interpreter');
    println('  neko - run tests on neko');
    println('  node - run tests on nodejs (with hxnodejs)');
    println('  js - run tests on js (with phantomjs)');
    println('  php - run tests on php 5.x');
    println('  php7 - run tests on php 7.x');
    println('  java - run tests on java');
    println('  flash - run tests on flash');
    println('  python - run tests on python');
    println('  cs - run tests on cs');
    println('  cpp - run tests on cpp');
    println('  lua - run tests on lua');
  }
}