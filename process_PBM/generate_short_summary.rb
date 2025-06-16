require 'optparse'

logo_folders = []
html_dest = nil
tsv_dest  = nil
option_parser = OptionParser.new{|opts|
  opts.on('--logos-source FOLDER'){|folder| logo_folders << folder }
  opts.on('--html-destination FILE'){|file| html_dest = file }
  opts.on('--tsv-destination FILE'){|file| tsv_dest = file }
}
option_parser.parse!(ARGV)

raise "Specify logos source folder" if logo_folders.empty?
raise "Specify html destination file" unless html_dest
raise "Specify tsv destination file" unless tsv_dest

# standard normal distribution quantiles
header = ['TF', 'method', 'motif']
header_classes = ['group-text', 'group-text', '', '']

# AHCTF1.R_2018-08-23_13497_1M-ME_Standard_pTH13913.1_AHCTF1.DBD.pbm.train.png
chip_infos = logo_folders.flat_map{|folder| Dir.glob(File.join(folder, '*.png')) }.map{|fn|
  method = File.basename(File.dirname(File.dirname(fn)))
  basename = File.basename(fn, ".png")
  tf = basename.split(".").first
  {tf:tf, basename: basename, method: method, logo: "<img src='#{method}/logo/#{basename}.png' />"}
}

File.open(html_dest, 'w'){|fw|
  fw.puts <<-EOS
    <html><head>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/css/theme.default.min.css" integrity="sha512-wghhOJkjQX0Lh3NSWvNKeZ0ZpNn+SPVXX1Qyc9OCaogADktxrBiBdKGDoqVUOyhStvMBmJQ8ZdMHiR3wuEq8+w==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.5.1/jquery.js" integrity="sha512-WNLxfP/8cVYL9sj8Jnp6et0BkubLP31jhTG9vhL/F5uEZmg5wEzKoXp1kJslzPQWwPT1eyMiSxlKCgzHLOTOTQ==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/js/jquery.tablesorter.js" integrity="sha512-5pW5mEMfVgzkFnOev2vr5P3CHDUB4K6okfAaJHXINoYVfynbiwJhU/OdeaVNjr1a5chNH0prZubh/VZoIqWRHw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/js/jquery.tablesorter.widgets.js" integrity="sha512-Rte4zWBBJ2qG37s6kTUiz0hvWgS2Mz9FnD8diPGhsaYNpE7zN9vvMu2DCLKGoHEfTpQdi9YF3HuqnzdpeIWmCQ==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/css/widget.grouping.min.css">
    <script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/js/widgets/widget-grouping.min.js"></script>
<style>
tr.group-header td {
  background: lightgray;
  padding: 20px;
}
tr.group-header td .group-name {
  margin-left: 100px;
}
td.group-name {
  text-transform: uppercase;
  font-weight: bold;
}
tr.group-header td {
  text-transform: uppercase;
}
.group-count {
  color: #999;
  display: none;
}
.group-hidden {
  display: none;
}
.group-header, .group-header td {
  user-select: none;
  -moz-user-select: none;
}
/* collapsed arrow */
tr.group-header td {
  height:35px;
}
tr.group-header td i {
  display: inline-block;
  width: 0;
  height: 0;
  border-top: 4px solid transparent;
  border-bottom: 4px solid #888;
  border-right: 4px solid #888;
  border-left: 4px solid transparent;
  margin-right: 7px;
  user-select: none;
  -moz-user-select: none;
}
tr.group-header.collapsed td i {
  border-top: 5px solid transparent;
  border-bottom: 5px solid transparent;
  border-left: 5px solid #888;
  border-right: 0;
  margin-right: 10px;
}
</style>
    </head><body>
  EOS

  fw.puts '<table class="tablesorter"><thead><tr>'
  fw.puts (header + ['logo']).zip(header_classes).map{|hdr, cls| "<th class='#{cls}'>#{hdr}</th>" }.join
  fw.puts '</tr></thead><tbody>'
  chip_infos.each{|info|
    fw.puts '<tr>'
    fw.puts info.values_at(:tf, :method, :basename, :logo).flatten.map{|hdr| "<td>#{hdr}</td>" }.join
    fw.puts '</tr>'
  }
  fw.puts '</tbody></table>'
  fw.puts <<-EOS
    <script>
    $(function() {
      $(".tablesorter").tablesorter({
        sortList: [[0,0],[1,0]],
        widgets:['group'],
        widgetOptions: {
          group_collapsible : true, 
          group_enforceSort : true,
          group_callback : function($cell, $rows, column, table) {
            $cell.find('.group-count').remove();
            if (column || true) {
              // callback allowing modification of the group header labels
              // $cell = current table cell (containing group header cells ".group-name" & ".group-count"
              // $rows = all of the table rows for the current group; table = current table (DOM)
              // column = current column being sorted/grouped
              let group_name = $cell.find('.group-name').text();
              $cell.html('<i></i><span class="group-name">' + group_name + '</span>')
            }
          },

        },
      });
    });
    </script>
    </body></html>
    EOS
}

File.open(tsv_dest, 'w'){|fw|
  fw.puts header.join("\t")
  chip_infos.each{|info|
    fw.puts info.values_at(:tf, :method, :basename).flatten.join("\t")
  }
}
