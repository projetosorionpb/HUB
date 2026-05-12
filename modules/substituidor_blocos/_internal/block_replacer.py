"""
DXF Block Replacer Engine
Handles loading DXF files, extracting block information, generating previews,
and performing block replacements.
"""
import ezdxf
from ezdxf.addons import Importer
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from ezdxf.addons.drawing import Frontend, RenderContext
from ezdxf.addons.drawing import matplotlib as ezdxf_mpl
import io
import base64
import json
import os
import copy


class BlockReplacer:
    def __init__(self):
        self.source_doc = None
        self.source_path = None
        self.target_docs = {}  # name -> doc
        self.target_paths = {}
        self.mapping = {}  # source_block_name -> {target_file, target_block_name}
        self.excel_data = None
    
    def load_excel(self, filepath):
        """Load Excel data for 100% accurate block parsing."""
        from excel_parser import ExcelData
        self.excel_data = ExcelData(filepath)
        return self.excel_data.get_summary()

    def load_source(self, filepath):
        """Load the source DXF file (from survey program)."""
        self.source_doc = ezdxf.readfile(filepath)
        self.source_path = filepath
    
    def load_target(self, filepath, label=None):
        """Load a DXF file containing project blocks."""
        if label is None:
            label = os.path.basename(filepath)
        doc = ezdxf.readfile(filepath)
        self.target_docs[label] = doc
        self.target_paths[label] = filepath
        return label
    
    def get_source_blocks(self):
        """Get list of blocks used in the source DXF modelspace (INSERT entities)."""
        if self.source_doc is None:
            return []
        
        msp = self.source_doc.modelspace()
        blocks = {}
        
        for entity in msp.query('INSERT'):
            name = entity.dxf.name
            if name.startswith('*'):
                continue
            if name not in blocks:
                block_def = self.source_doc.blocks.get(name)
                entity_count = len(list(block_def)) if block_def else 0
                blocks[name] = {
                    'name': name,
                    'count': 0,
                    'layer': entity.dxf.layer,
                    'entity_count': entity_count,
                }
            blocks[name]['count'] += 1
        
        return sorted(blocks.values(), key=lambda x: x['name'])
    
    def get_all_source_block_definitions(self):
        """Get ALL block definitions from source DXF (not just used ones)."""
        if self.source_doc is None:
            return []
        
        msp = self.source_doc.modelspace()
        used_blocks = set()
        for entity in msp.query('INSERT'):
            used_blocks.add(entity.dxf.name)
        
        blocks = []
        for block in self.source_doc.blocks:
            name = block.name
            if name.startswith('*') or name in ['_ARCHTICK', '_CLOSEDFILLED', '_CLOSEDBLANK']:
                continue
            entities = list(block)
            if len(entities) == 0:
                continue
            blocks.append({
                'name': name,
                'entity_count': len(entities),
                'is_used': name in used_blocks,
                'usage_count': sum(1 for e in msp.query('INSERT') if e.dxf.name == name) if name in used_blocks else 0
            })
        
        return sorted(blocks, key=lambda x: (-x['is_used'], x['name']))
    
    def get_target_blocks(self, label=None):
        """Get list of block definitions from target DXF file(s)."""
        result = []
        
        docs_to_scan = {}
        if label:
            if label in self.target_docs:
                docs_to_scan[label] = self.target_docs[label]
        else:
            docs_to_scan = self.target_docs
        
        for doc_label, doc in docs_to_scan.items():
            # Get blocks inserted in modelspace (with positions for context)
            msp = doc.modelspace()
            msp_inserts = {}
            msp_texts = []
            
            for entity in msp:
                if entity.dxftype() == 'INSERT':
                    name = entity.dxf.name
                    pos = (round(entity.dxf.insert.x, 2), round(entity.dxf.insert.y, 2))
                    if name not in msp_inserts:
                        msp_inserts[name] = []
                    msp_inserts[name].append(pos)
                elif entity.dxftype() in ('TEXT', 'MTEXT'):
                    text = entity.dxf.text if entity.dxftype() == 'TEXT' else entity.text
                    pos = (round(entity.dxf.insert.x, 2), round(entity.dxf.insert.y, 2))
                    msp_texts.append({'text': text, 'pos': pos})
            
            for block in doc.blocks:
                name = block.name
                if name.startswith('*') or name in ['_ARCHTICK', '_CLOSEDFILLED', '_CLOSEDBLANK', '_DOT', '_OPEN30']:
                    continue
                entities = list(block)
                if len(entities) == 0:
                    continue
                
                result.append({
                    'name': name,
                    'file': doc_label,
                    'entity_count': len(entities),
                    'in_modelspace': name in msp_inserts,
                    'positions': msp_inserts.get(name, []),
                })
        
        return sorted(result, key=lambda x: x['name'])
    
    def render_block_preview(self, block_name, source='source', target_label=None):
        """Render a block as a base64-encoded PNG image."""
        try:
            if source == 'source':
                doc = self.source_doc
            else:
                doc = self.target_docs.get(target_label)
            
            if doc is None:
                return None
            
            block = doc.blocks.get(block_name)
            if block is None:
                return None
            
            entities = list(block)
            if len(entities) == 0:
                return None
            
            # Create temp doc
            temp_doc = ezdxf.new()
            temp_msp = temp_doc.modelspace()
            
            # Import the block
            importer = Importer(doc, temp_doc)
            importer.import_block(block_name)
            importer.finalize()
            
            # Insert block reference
            temp_msp.add_blockref(block_name, insert=(0, 0))
            
            # Render using matplotlib
            fig, ax = plt.subplots(1, 1, figsize=(2.5, 2.5), dpi=100)
            ax.set_aspect('equal')
            ax.set_axis_off()
            fig.patch.set_facecolor('#1a1a2e')
            ax.set_facecolor('#1a1a2e')
            
            ctx = RenderContext(temp_doc)
            out = ezdxf_mpl.MatplotlibBackend(ax)
            Frontend(ctx, out).draw_layout(temp_msp, finalize=True)
            
            # Change line colors to be visible on dark background
            for line in ax.get_lines():
                line.set_color('#4ECDC4')
            for patch in ax.patches:
                patch.set_edgecolor('#4ECDC4')
            for collection in ax.collections:
                collection.set_edgecolor('#4ECDC4')
            
            buf = io.BytesIO()
            fig.savefig(buf, format='png', bbox_inches='tight', 
                       facecolor='#1a1a2e', edgecolor='none', pad_inches=0.1)
            plt.close(fig)
            buf.seek(0)
            
            return base64.b64encode(buf.read()).decode('utf-8')
        except Exception as e:
            print(f'Error rendering block {block_name}: {e}')
            return None
    
    def set_mapping(self, source_block, target_file, target_block):
        """Set a mapping from source block to target block."""
        self.mapping[source_block] = {
            'target_file': target_file,
            'target_block': target_block
        }
    
    def remove_mapping(self, source_block):
        """Remove a mapping."""
        if source_block in self.mapping:
            del self.mapping[source_block]
    
    def get_mapping(self):
        """Get current mapping."""
        return self.mapping
    
    def save_mapping(self, filepath):
        """Save mapping to JSON file."""
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(self.mapping, f, indent=2, ensure_ascii=False)
    
    def load_mapping(self, filepath):
        """Load mapping from JSON file."""
        with open(filepath, 'r', encoding='utf-8') as f:
            self.mapping = json.load(f)
    
    def _recenter_block(self, doc, block_name, threshold=50.0):
        """
        Auto-recenter a block definition if its internal geometry is far from (0,0).
        Fixes blocks clipboard-copied from large-coordinate (UTM) drawings.
        """
        block = doc.blocks.get(block_name)
        if block is None:
            return (0.0, 0.0)
        
        bx, by = [], []
        for ent in block:
            t = ent.dxftype()
            try:
                if t == 'LINE':
                    bx += [ent.dxf.start.x, ent.dxf.end.x]
                    by += [ent.dxf.start.y, ent.dxf.end.y]
                elif t == 'LWPOLYLINE':
                    for p in ent.get_points(format='xy'):
                        bx.append(p[0]); by.append(p[1])
                elif t in ('CIRCLE', 'ARC', 'ELLIPSE'):
                    bx.append(ent.dxf.center.x); by.append(ent.dxf.center.y)
                elif t == 'INSERT':
                    bx.append(ent.dxf.insert.x); by.append(ent.dxf.insert.y)
                elif t == 'POINT':
                    bx.append(ent.dxf.location.x); by.append(ent.dxf.location.y)
                elif t in ('TEXT', 'MTEXT'):
                    bx.append(ent.dxf.insert.x); by.append(ent.dxf.insert.y)
            except:
                pass
        
        if not bx:
            return (0.0, 0.0)
        
        cx = (min(bx) + max(bx)) / 2.0
        cy = (min(by) + max(by)) / 2.0
        
        if abs(cx) < threshold and abs(cy) < threshold:
            return (0.0, 0.0)
        
        print(f"  Recentering block '{block_name}': shift ({-cx:.1f}, {-cy:.1f})")
        
        for ent in block:
            t = ent.dxftype()
            try:
                if t == 'LINE':
                    s, e = ent.dxf.start, ent.dxf.end
                    ent.dxf.start = (s.x - cx, s.y - cy, s.z)
                    ent.dxf.end = (e.x - cx, e.y - cy, e.z)
                elif t == 'LWPOLYLINE':
                    pts = ent.get_points(format='xyseb')
                    ent.set_points([(p[0]-cx, p[1]-cy, p[2], p[3], p[4]) for p in pts], format='xyseb')
                elif t in ('CIRCLE', 'ARC', 'ELLIPSE'):
                    c = ent.dxf.center
                    ent.dxf.center = (c.x - cx, c.y - cy, c.z)
                elif t == 'INSERT':
                    i = ent.dxf.insert
                    ent.dxf.insert = (i.x - cx, i.y - cy, i.z)
                elif t == 'POINT':
                    l = ent.dxf.location
                    ent.dxf.location = (l.x - cx, l.y - cy, l.z)
                elif t == 'TEXT':
                    i = ent.dxf.insert
                    ent.dxf.insert = (i.x - cx, i.y - cy, i.z)
                    if ent.dxf.hasattr('align_point'):
                        a = ent.dxf.align_point
                        ent.dxf.align_point = (a.x - cx, a.y - cy, a.z)
                elif t == 'MTEXT':
                    i = ent.dxf.insert
                    ent.dxf.insert = (i.x - cx, i.y - cy, i.z)
                elif t == 'SPLINE':
                    ent.control_points = [(p[0]-cx, p[1]-cy, p[2]) for p in ent.control_points]
                    if ent.fit_points:
                        ent.fit_points = [(p[0]-cx, p[1]-cy, p[2]) for p in ent.fit_points]
                elif t in ('SOLID', '3DFACE', 'TRACE'):
                    for attr in ('vtx0', 'vtx1', 'vtx2', 'vtx3'):
                        if ent.dxf.hasattr(attr):
                            v = getattr(ent.dxf, attr)
                            setattr(ent.dxf, attr, (v.x - cx, v.y - cy, v.z))
            except Exception as ex:
                print(f"    Warning: Could not shift {t}: {ex}")
        
        return (cx, cy)
    
    def _compute_centroid(self, doc):
        """Compute the centroid of all entities in modelspace for use as scale reference."""
        msp = doc.modelspace()
        all_x = []
        all_y = []
        
        for entity in msp:
            dxftype = entity.dxftype()
            try:
                if dxftype == 'LINE':
                    all_x.extend([entity.dxf.start.x, entity.dxf.end.x])
                    all_y.extend([entity.dxf.start.y, entity.dxf.end.y])
                elif dxftype == 'LWPOLYLINE':
                    for p in entity.get_points(format='xy'):
                        all_x.append(p[0])
                        all_y.append(p[1])
                elif dxftype in ('CIRCLE', 'ARC'):
                    all_x.append(entity.dxf.center.x)
                    all_y.append(entity.dxf.center.y)
                elif dxftype in ('TEXT', 'MTEXT'):
                    all_x.append(entity.dxf.insert.x)
                    all_y.append(entity.dxf.insert.y)
                elif dxftype == 'INSERT':
                    all_x.append(entity.dxf.insert.x)
                    all_y.append(entity.dxf.insert.y)
                elif dxftype == 'POINT':
                    all_x.append(entity.dxf.location.x)
                    all_y.append(entity.dxf.location.y)
            except:
                pass
        
        if all_x:
            cx = sum(all_x) / len(all_x)
            cy = sum(all_y) / len(all_y)
            return (cx, cy)
        return (0.0, 0.0)
    
    def scale_geometry(self, doc, scale_factor):
        """
        Scale all geometry in the modelspace by scale_factor, relative to
        the centroid of the drawing (NOT from origin 0,0).
        INSERT entities (blocks) have only their insertion point scaled,
        NOT their xscale/yscale/zscale, so blocks keep their original size.
        """
        msp = doc.modelspace()
        sf = scale_factor
        cx, cy = self._compute_centroid(doc)
        scaled_count = 0
        
        def scale_pt(x, y, z=0.0):
            """Scale a point relative to centroid."""
            return (cx + (x - cx) * sf, cy + (y - cy) * sf, z)
        
        for entity in msp:
            dxftype = entity.dxftype()
            try:
                if dxftype == 'LINE':
                    s = entity.dxf.start
                    e = entity.dxf.end
                    entity.dxf.start = scale_pt(s.x, s.y, s.z)
                    entity.dxf.end = scale_pt(e.x, e.y, e.z)
                    scaled_count += 1
                    
                elif dxftype == 'LWPOLYLINE':
                    points = entity.get_points(format='xyseb')
                    new_points = []
                    for p in points:
                        sx, sy, _ = scale_pt(p[0], p[1])
                        new_points.append((
                            sx, sy,
                            p[2] * sf, p[3] * sf, p[4]
                        ))
                    entity.set_points(new_points, format='xyseb')
                    scaled_count += 1
                    
                elif dxftype == 'CIRCLE':
                    c = entity.dxf.center
                    entity.dxf.center = scale_pt(c.x, c.y, c.z)
                    # Do not scale radius so bubbles remain proportional to the fixed-size text
                    scaled_count += 1
                    
                elif dxftype == 'ARC':
                    c = entity.dxf.center
                    entity.dxf.center = scale_pt(c.x, c.y, c.z)
                    entity.dxf.radius = entity.dxf.radius * sf
                    scaled_count += 1
                    
                elif dxftype == 'ELLIPSE':
                    c = entity.dxf.center
                    entity.dxf.center = scale_pt(c.x, c.y, c.z)
                    maj = entity.dxf.major_axis
                    entity.dxf.major_axis = (maj.x * sf, maj.y * sf, maj.z * sf)
                    scaled_count += 1
                    
                elif dxftype == 'POINT':
                    loc = entity.dxf.location
                    entity.dxf.location = scale_pt(loc.x, loc.y, loc.z)
                    scaled_count += 1
                    
                elif dxftype == 'TEXT':
                    ins = entity.dxf.insert
                    entity.dxf.insert = scale_pt(ins.x, ins.y, ins.z)
                    if entity.dxf.hasattr('align_point'):
                        ap = entity.dxf.align_point
                        entity.dxf.align_point = scale_pt(ap.x, ap.y, ap.z)
                    entity.dxf.height = 1.5  # Fixed text height
                    scaled_count += 1
                    
                elif dxftype == 'MTEXT':
                    ins = entity.dxf.insert
                    entity.dxf.insert = scale_pt(ins.x, ins.y, ins.z)
                    entity.dxf.char_height = 1.5  # Fixed text height
                    if entity.dxf.hasattr('width'):
                        entity.dxf.width = entity.dxf.width * sf
                    scaled_count += 1
                    
                elif dxftype == 'INSERT':
                    # Scale ONLY the insertion point, NOT the block scale
                    ins = entity.dxf.insert
                    entity.dxf.insert = scale_pt(ins.x, ins.y, ins.z)
                    scaled_count += 1
                    
                elif dxftype == 'SPLINE':
                    ctrl_pts = entity.control_points
                    new_pts = [scale_pt(p[0], p[1], p[2]) for p in ctrl_pts]
                    entity.control_points = new_pts
                    if entity.fit_points:
                        fit_pts = entity.fit_points
                        entity.fit_points = [scale_pt(p[0], p[1], p[2]) for p in fit_pts]
                    scaled_count += 1
                    
                elif dxftype in ('SOLID', '3DFACE', 'TRACE'):
                    for attr in ('vtx0', 'vtx1', 'vtx2', 'vtx3'):
                        if entity.dxf.hasattr(attr):
                            v = getattr(entity.dxf, attr)
                            setattr(entity.dxf, attr, scale_pt(v.x, v.y, v.z))
                    scaled_count += 1
                    
                elif dxftype == 'DIMENSION':
                    for attr in ('defpoint', 'defpoint2', 'defpoint3', 'defpoint4', 'defpoint5',
                                 'text_midpoint', 'insert'):
                        if entity.dxf.hasattr(attr):
                            p = getattr(entity.dxf, attr)
                            setattr(entity.dxf, attr, scale_pt(p.x, p.y, p.z))
                    scaled_count += 1
                    
                elif dxftype == 'LEADER':
                    vertices = entity.vertices
                    if vertices:
                        new_verts = [scale_pt(v.x, v.y, v.z) for v in vertices]
                        entity.set_vertices(new_verts)
                    scaled_count += 1
                    
                elif dxftype == 'HATCH':
                    # Skip hatch scaling - complex boundary handling
                    pass
                    
            except Exception as e:
                print(f"Warning: Could not scale {dxftype} entity: {e}")
        
        print(f"Scaled {scaled_count} entities by factor {sf} (centroid: {cx:.1f}, {cy:.1f})")
        return scaled_count
    
    def replace_blocks(self, output_path=None, scale_factor=1.0):
        """
        Execute block replacement based on current mapping.
        Compensates for base_point differences between source and target blocks.
        If scale_factor != 1.0, scales all geometry by the factor but keeps
        block (INSERT) sizes unchanged (only repositions insertion points).
        Returns the output file path.
        """
        if self.source_doc is None:
            raise ValueError("No source DXF loaded")
        
        if not self.mapping:
            raise ValueError("No block mappings defined")
        
        if output_path is None:
            base, ext = os.path.splitext(self.source_path)
            output_path = f"{base}_MODIFICADO{ext}"
        
        # Read fresh copy
        doc = ezdxf.readfile(self.source_path)
        msp = doc.modelspace()
        
        # Collect source block base_points before importing target blocks
        source_base_points = {}
        for source_name in self.mapping:
            src_block = doc.blocks.get(source_name)
            if src_block is not None:
                bp = src_block.base_point
                source_base_points[source_name] = (bp[0], bp[1], bp[2] if len(bp) > 2 else 0.0)
            else:
                source_base_points[source_name] = (0.0, 0.0, 0.0)
        
        # Import target blocks
        imported_blocks = set()
        target_base_points = {}
        renamed_blocks = {}  # old_temp_name -> original_name
        
        for source_name, target_info in self.mapping.items():
            target_file = target_info['target_file']
            target_block = target_info['target_block']
            
            if target_block not in imported_blocks:
                target_doc = self.target_docs.get(target_file)
                if target_doc is None:
                    continue
                
                # Check if target block exists in target doc
                tgt_block_def = target_doc.blocks.get(target_block)
                if tgt_block_def is None:
                    continue
                
                # Store target base_point before import
                tgt_bp = tgt_block_def.base_point
                target_base_points[target_block] = (tgt_bp[0], tgt_bp[1], tgt_bp[2] if len(tgt_bp) > 2 else 0.0)
                
                # If a block with the same name already exists in source doc,
                # rename it first so the import doesn't get skipped
                existing_block = doc.blocks.get(target_block)
                if existing_block is not None:
                    temp_name = f"_OLD_{target_block}"
                    print(f"  Renaming existing '{target_block}' -> '{temp_name}' to allow import")
                    doc.blocks.rename_block(target_block, temp_name)
                    # Update all INSERT references to use temp name
                    for ent in msp.query('INSERT'):
                        if ent.dxf.name == target_block:
                            ent.dxf.name = temp_name
                    renamed_blocks[temp_name] = target_block
                
                # Import block definition
                try:
                    importer = Importer(target_doc, doc)
                    importer.import_block(target_block)
                    importer.finalize()
                    imported_blocks.add(target_block)
                    
                    # Auto-recenter was removed because it destroys internal geometry of nested blocks
                    # self._recenter_block(doc, target_block)
                    print(f"  Imported target block '{target_block}'")
                except Exception as e:
                    print(f"Error importing block {target_block}: {e}")
                    continue
        
        # Build reverse lookup: temp_name -> original source name
        temp_to_source = {v: v for v in self.mapping}  # identity for normal names
        for temp_name, orig_name in renamed_blocks.items():
            temp_to_source[temp_name] = orig_name
        
        # Replace block references (compensate for base_point differences)
        replacements = 0
        for entity in msp.query('INSERT'):
            name = entity.dxf.name
            # Check if this name (or its temp-renamed version) is in the mapping
            source_name = temp_to_source.get(name)
            if source_name and source_name in self.mapping:
                target_info = self.mapping[source_name]
                target_block = target_info['target_block']
                
                if target_block in imported_blocks:
                    # Compensate for base_point difference
                    src_bp = source_base_points.get(source_name, (0.0, 0.0, 0.0))
                    tgt_bp = target_base_points.get(target_block, (0.0, 0.0, 0.0))
                    
                    # Adjust insertion point: old_insert accounts for src_bp offset,
                    # new block needs to account for tgt_bp offset
                    ins = entity.dxf.insert
                    dx = src_bp[0] - tgt_bp[0]
                    dy = src_bp[1] - tgt_bp[1]
                    dz = src_bp[2] - tgt_bp[2]
                    entity.dxf.insert = (ins.x + dx, ins.y + dy, ins.z + dz)
                    
                    entity.dxf.name = target_block
                    replacements += 1
                    
                    if dx != 0 or dy != 0:
                        print(f"  Adjusted {name}->{target_block}: offset=({dx:.2f}, {dy:.2f})")
        
        # Apply scale if needed (after block replacement)
        scaled_entities = 0
        if scale_factor != 1.0:
            scaled_entities = self.scale_geometry(doc, scale_factor)
        
        # Convert and format TEXT entities
        import re
        texts_converted = 0
        
        # Process MTEXT entities
        for mtext_ent in [e for e in msp if e.dxftype() == 'MTEXT']:
            if not mtext_ent.dxf.hasattr('layer'): continue
            layer = mtext_ent.dxf.layer
            content = mtext_ent.text
            
            # Rule 1: Point names
            if re.match(r'^P\d+$', content.strip()):
                mtext_ent.text = f"F.{content.strip()}"
                mtext_ent.dxf.color = 5
            
            # Rule 1.5: REMOVER layers
            elif 'REMOVER' in layer.upper():
                mtext_ent.dxf.color = 256
                mtext_ent.dxf.true_color = (51 << 16) | (51 << 8) | 51
            
            # Rule 2: Coordinate format
            elif 'X:' in content and 'Y:' in content:
                match = re.search(r'X:\s*([\d\.]+).*?Y:\s*([\d\.]+)', content)
                if match:
                    x_val = int(float(match.group(1)))
                    y_val = int(float(match.group(2)))
                    mtext_ent.text = f"X: {x_val}\nY: {y_val}"
            
            # Rule 3: D -> DT for standalone poles
            if re.match(r'^D\d+', mtext_ent.text.strip()):
                mtext_ent.text = re.sub(r'^D(\d+)', r'DT\1', mtext_ent.text.strip())

        text_entities = [e for e in msp if e.dxftype() == 'TEXT']
        for text_ent in text_entities:
            try:
                content = text_ent.dxf.text
                halign = text_ent.dxf.get('halign', 0)
                valign = text_ent.dxf.get('valign', 0)
                
                # Use align_point if alignment is not default (left, baseline)
                if (halign != 0 or valign != 0) and text_ent.dxf.hasattr('align_point'):
                    ins = text_ent.dxf.align_point
                else:
                    ins = text_ent.dxf.insert
                    
                layer = text_ent.dxf.layer
                rotation = text_ent.dxf.get('rotation', 0.0)
                color = text_ent.dxf.get('color', 256)  # 256 = BYLAYER
                true_color = None
                
                # Rule 1: Point names (P1 -> F.P1 in blue)
                if re.match(r'^P\d+$', content.strip()):
                    content = f"F.{content.strip()}"
                    color = 5  # AutoCAD color index for Blue
                
                # Rule 1.5: REMOVER layers (True Color RGB 51,51,51)
                elif 'REMOVER' in layer.upper():
                    color = 256 # Fallback
                    true_color = (51 << 16) | (51 << 8) | 51
                
                # Rule 2: Coordinate format (X/Y ints only)
                elif 'X:' in content and 'Y:' in content:
                    # Extract X and Y using regex
                    match = re.search(r'X:\s*([\d\.]+).*?Y:\s*([\d\.]+)', content)
                    if match:
                        x_val = int(float(match.group(1)))
                        y_val = int(float(match.group(2)))
                        content = f"X: {x_val}\nY: {y_val}"

                # Rule 3: D -> DT for standalone poles
                if re.match(r'^D\d+', content.strip()):
                    content = re.sub(r'^D(\d+)', r'DT\1', content.strip())
                
                # Create MTEXT replacement
                attribs = {
                    'insert': (ins.x, ins.y, ins.z),
                    'char_height': 1.5,
                    'layer': layer,
                    'rotation': rotation,
                    'color': color,
                    'attachment_point': 1,  # Top-left
                }
                if true_color is not None:
                    attribs['true_color'] = true_color
                    
                mtext = msp.add_mtext(content, dxfattribs=attribs)
                
                msp.delete_entity(text_ent)
                texts_converted += 1
            except Exception as e:
                print(f"Warning: Could not convert TEXT to MTEXT: {e}")
        
        if texts_converted > 0:
            print(f"Converted {texts_converted} TEXT entities to MTEXT")
        
        # FIRST PASS: Delete boundaries (LWPOLYLINEs on TEXTOS layers)
        polys_to_delete = []
        for e in msp:
            if e.dxftype() == 'LWPOLYLINE' and getattr(e.dxf, 'layer', '').startswith('TEXTOS'):
                polys_to_delete.append(e)
        for e in polys_to_delete:
            try:
                msp.delete_entity(e)
            except:
                pass

        # SECOND PASS: Gather texts on TEXTOS layers and group by EXACT layer name
        import re
        import math as _math

        def _is_poste(txt):
            """Poste: ex. D11/300, DT8/600 (after D->DT conversion)"""
            return bool(re.match(r'^D[T]?\d+/', txt.strip()))

        def _is_estrutura(txt):
            """
            Estrutura: ex. N1, S2, SI-1, U3, CE3, N1 N3, CE3 N3 - NOT cable notes.
            Strategy: negative filtering - reject anything that looks like a cable,
            coordinate, or poste. Accept everything else that looks like a short code.
            """
            t = txt.strip()
            if not t:
                return False
            # Must not be a poste itself
            if _is_poste(t):
                return False
            # Must not contain cable/voltage keywords
            if any(kw in t for kw in ("#", "BT", "MT", "kV", "X:", "Y:")):
                return False
            # Must not look like a cable size (e.g. "M3x1x70", "CAA 4/0")
            if re.search(r'\b(M\d|CA[A]?|CAZ)\b', t):
                return False
            # Must not be a distance/length (e.g. "19 m", "28m")
            if re.search(r'\d+\s*m\b', t):
                return False
            # Must not be a coordinate value
            if re.search(r'\d{5,}', t):
                return False
            # Must be composed only of uppercase letters, digits, spaces, hyphens, slashes
            if not re.match(r'^[A-Z0-9][A-Za-z0-9\s/\-]*$', t):
                return False
            # Must be reasonably short (structure codes are brief)
            if len(t) > 30:
                return False
            return True

        # Collect all candidate texts grouped by layer
        layer_groups = {}  # layer_name -> list of dicts
        for e in msp:
            if e.dxftype() not in ('TEXT', 'MTEXT'):
                continue
            layer = getattr(e.dxf, 'layer', '')
            if not layer.startswith('TEXTOS'):
                continue
            text_val = (e.dxf.text if e.dxftype() == 'TEXT' else e.text).strip()
            if not text_val:
                continue
            pos = e.dxf.insert
            entry = {
                'ent': e,
                'text': text_val,
                'x': pos.x,
                'y': pos.y,
                'layer': layer,
                'is_poste': _is_poste(text_val),
                'is_estrutura': _is_estrutura(text_val),
            }
            layer_groups.setdefault(layer, []).append(entry)

        # THIRD PASS: For each layer, do exclusive nearest-neighbor pairing
        # Max euclidean distance to consider a pair (in drawing units)
        MAX_MERGE_DIST = 50.0

        merged_count = 0
        excel_matched_count = 0

        for layer_name, items in layer_groups.items():
            postes    = [t for t in items if t['is_poste']]
            estruturas = [t for t in items if t['is_estrutura']]

            if not postes:
                continue

            used_postes = set()
            used_estrs  = set()

            # Optional: Match from Excel if loaded
            if self.excel_data:
                for p_item in postes:
                    match = re.match(r'^D[T]?(\d+)', p_item['text'].strip())
                    if not match:
                        continue
                    
                    poste_num = match.group(1)
                    
                    # Fetch from Excel
                    estrs = self.excel_data.get_estruturas_for_poste(poste_num)
                    if estrs:
                        # Build merged text from Excel
                        poste_str = re.sub(r'^D(\d+)', r'DT\1', p_item['text'])
                        
                        estr_parts = []
                        for e in estrs:
                            if e['tipo'] == 'MT':
                                estr_parts.append(f"1-{e['estrutura']}")
                            else:
                                estr_parts.append(e['estrutura'])
                                
                        combined_text = f"{poste_str} {' '.join(estr_parts)}"
                        
                        # Write to poste entity
                        ent_poste = p_item['ent']
                        if ent_poste.dxftype() == 'TEXT':
                            ent_poste.dxf.text = combined_text
                        else:
                            ent_poste.text = combined_text
                            
                        # Mark this as solved
                        p_id = id(p_item['ent'])
                        used_postes.add(p_id)
                        excel_matched_count += 1
                        print(f"  Excel Match [{layer_name}] Poste {poste_num} -> '{combined_text}'")
                        
                        # Optimization: we can delete the floating estrut objects near this poste to avoid duplicate text
                        for e_item in estruturas:
                            if id(e_item['ent']) in used_estrs: continue
                            dist = _math.hypot(p_item['x'] - e_item['x'], p_item['y'] - e_item['y'])
                            if dist <= MAX_MERGE_DIST:
                                try:
                                    msp.delete_entity(e_item['ent'])
                                    used_estrs.add(id(e_item['ent']))
                                except:
                                    pass

            # Fallback to nearest neighbor for remaining unmatched postes
            unmatched_postes = [p for p in postes if id(p['ent']) not in used_postes]
            unmatched_estrs = [e for e in estruturas if id(e['ent']) not in used_estrs]

            if not unmatched_postes or not unmatched_estrs:
                continue

            # Build a cost matrix (euclidean distance) and greedily assign
            pairs = []
            for p in unmatched_postes:
                for e in unmatched_estrs:
                    dist = _math.hypot(p['x'] - e['x'], p['y'] - e['y'])
                    if dist <= MAX_MERGE_DIST:
                        pairs.append((dist, p, e))

            # Sort by distance ascending
            pairs.sort(key=lambda x: x[0])

            for dist, p_item, e_item in pairs:
                p_id = id(p_item['ent'])
                e_id = id(e_item['ent'])
                if p_id in used_postes or e_id in used_estrs:
                    continue  # already matched

                # Build merged text
                poste_str = re.sub(r'^D(\d+)', r'DT\1', p_item['text'])
                estr_str  = e_item['text']
                if not estr_str.startswith('1-'):
                    estr_str = '1-' + estr_str
                combined_text = f"{poste_str} {estr_str}"

                # Write to poste entity, delete estrutura entity
                ent_poste = p_item['ent']
                ent_estr  = e_item['ent']
                if ent_poste.dxftype() == 'TEXT':
                    ent_poste.dxf.text = combined_text
                else:
                    ent_poste.text = combined_text
                try:
                    msp.delete_entity(ent_estr)
                except Exception:
                    pass

                used_postes.add(p_id)
                used_estrs.add(e_id)
                merged_count += 1
                print(f"  Fallback Merged [{layer_name}] dist={dist:.1f} -> '{combined_text}'")

        if excel_matched_count > 0:
            print(f"Formatted {excel_matched_count} text pairs (poste + estrutura) based strictly on Excel validation.")
        if merged_count > 0:
            print(f"Merged {merged_count} remaining text pairs using fallback nearest-neighbor pairing.")

        # --- NOVO: REFORMATAR VÃOS (SPAN ANNOTATIONS) E SUAS BOLHAS ---
        vaos_formatados = 0
        import re
        
        for e in msp:
            if e.dxftype() in ('TEXT', 'MTEXT'):
                if not e.dxf.hasattr('layer'): continue
                layer = e.dxf.layer
                if not layer.startswith('TEXTOS'): continue
                
                text_val = e.dxf.text if e.dxftype() == 'TEXT' else e.text
                text_val = text_val.strip()
                
                # Regex to capture: (length)m (BT|MT) (fases)#(cabo) (optional voltage)
                match = re.match(r'^(\d+)m\s+(BT|MT)\s+([A-Z0-9]+)#([A-Z0-9()]+)(?:\s+13\.8kV)?$', text_val)
                if match:
                    length = match.group(1)
                    voltage = match.group(2)
                    fases = match.group(3)
                    cabo = match.group(4)
                    
                    # Remove 'N' from phases (e.g. ABN -> AB)
                    fases = fases.replace('N', '')
                    
                    new_text = text_val
                    
                    if voltage == "BT":
                        m_cable = re.match(r'^M(\d+)(?:\((\d+)\))?$', cabo)
                        if m_cable:
                            size_val = m_cable.group(1)
                            neutral_val = m_cable.group(2) if m_cable.group(2) else size_val
                            if size_val == "25":
                                size_val = "35"
                                neutral_val = "35"
                            if "ABC" in fases:
                                new_text = f"M3x1x{size_val}+{neutral_val} {fases} {length} m"
                            else:
                                new_text = f"M2x1x{size_val}+{neutral_val} {fases} {length} m"
                    else:
                        p_cable = re.match(r'^P(\d+)$', cabo)
                        if p_cable:
                            size_val = p_cable.group(1)
                            
                            # Based on reference image, P50 creates a multi-line MTEXT:
                            # P50
                            # CAZ 9,5 ABC 40 m
                            # (Let's assume the bottom line is always CAZ 9,5 ABC for P50/120/185 based on user image)
                            new_text = f"P{size_val}\nCAZ 9,5 {fases} {length} m"
                        elif cabo.startswith("CAA"):
                            size_val = cabo[3:] 
                            new_text = f"CAA {size_val} {fases} {length} m"
                        elif cabo.startswith("CA"):
                            size_val = cabo[2:] 
                            new_text = f"CA {size_val} {fases} {length} m"
                            
                    if new_text != text_val:
                        # Update text entity
                        if e.dxftype() == 'TEXT':
                            e.dxf.text = new_text
                        else:
                            e.text = new_text
                            
                        vaos_formatados += 1
                        print(f"  Formatted Vão -> '{new_text}'")

        if vaos_formatados > 0:
            print(f"Formatted {vaos_formatados} Vão annotations.")

        # --- NOVO: GERAR BOLHAS NOVAS DO ZERO ---
        import math
        from ezdxf.math import Vec3
        bolhas_geradas = 0
        
        for e in msp:
            if e.dxftype() in ('TEXT', 'MTEXT'):
                if not e.dxf.hasattr('layer'): continue
                layer = e.dxf.layer
                if not layer.startswith('TEXTOS'): continue
                
                text_val = e.dxf.text if e.dxftype() == 'TEXT' else e.text
                if not text_val or not text_val.strip(): continue
                
                # Filter to only generate bubbles for texts to be implemented (Red)
                color = e.dxf.get('color', 256)
                is_red = (color == 1) or (color == 256 and 'IMPLANTAR' in layer.upper())
                if not is_red:
                    continue
                    
                
                char_height = getattr(e.dxf, 'char_height', 1.5)
                # Fallback para height
                if e.dxftype() == 'TEXT' and hasattr(e.dxf, 'height'):
                     char_height = e.dxf.height
                     
                insert = e.dxf.insert
                rot_deg = e.dxf.get('rotation', 0)
                rot_rad = math.radians(rot_deg)
                
                lines = text_val.split('\n')
                max_len = max(len(l) for l in lines)
                
                # Approximate dimensions
                est_width = char_height * 0.70 * max_len
                est_height = char_height * (len(lines) + 0.3)
                
                attach = getattr(e.dxf, 'attachment_point', 1) if e.dxftype() == 'MTEXT' else 7
                
                pad_x = char_height * 0.4
                pad_y = char_height * 0.2
                
                # X alignment
                if attach in (1, 4, 7): # Left
                    dx_min = -pad_x
                    dx_max = est_width + pad_x
                elif attach in (2, 5, 8): # Center
                    dx_min = -(est_width / 2) - pad_x
                    dx_max = (est_width / 2) + pad_x
                else: # Right (3, 6, 9)
                    dx_min = -est_width - pad_x
                    dx_max = pad_x
                    
                # Y alignment
                if attach in (1, 2, 3): # Top
                    dy_max = pad_y
                    dy_min = -est_height - pad_y
                elif attach in (4, 5, 6): # Middle
                    dy_max = (est_height / 2) + pad_y
                    dy_min = -(est_height / 2) - pad_y
                else: # Bottom (7, 8, 9)
                    dy_min = -pad_y
                    dy_max = est_height + pad_y
                    
                pts_local = [
                    Vec3(dx_min, dy_min),
                    Vec3(dx_max, dy_min),
                    Vec3(dx_max, dy_max),
                    Vec3(dx_min, dy_max)
                ]
                
                pts_world = []
                for p in pts_local:
                    rx = p.x * math.cos(rot_rad) - p.y * math.sin(rot_rad)
                    ry = p.x * math.sin(rot_rad) + p.y * math.cos(rot_rad)
                    pts_world.append((insert.x + rx, insert.y + ry))
                
                pts_world.append(pts_world[0]) # Close box
                
                msp.add_lwpolyline(pts_world, format='xy', dxfattribs={'layer': layer, 'color': 1})
                bolhas_geradas += 1

        print(f"Generated {bolhas_geradas} exact boundary bubbles strictly from text attributes.")
        
        # --- SUBSTITUIR X POR RISCO HORIZONTAL (STRIKETHROUGH) ---
        # Two-phase approach:
        # PHASE 1: Detect which texts need formatting (no lines generated yet!)
        # PHASE 2: Apply formatting + generate strikethrough lines
        # This prevents newly created lines from contaminating detection of adjacent texts.

        linhas_apagadas = 0
        strikethroughs_gerados = 0

        # Snapshot all existing LINE entities BEFORE any strikethrough is generated
        existing_lines = list(msp.query('LINE'))

        # Helper to compute text bounding box in local coords
        def _text_bbox(e):
            text_val = e.dxf.text if e.dxftype() == 'TEXT' else e.text
            if not text_val or not text_val.strip():
                return None
            ch = getattr(e.dxf, 'char_height', 1.5)
            if e.dxftype() == 'TEXT' and hasattr(e.dxf, 'height'):
                ch = e.dxf.height
            insert = e.dxf.insert
            rot_deg = e.dxf.get('rotation', 0.0)
            rot_rad = math.radians(rot_deg)
            lines_list = text_val.split('\n')
            max_len = max(len(l) for l in lines_list)
            est_w = ch * 0.70 * max_len
            est_h = ch * (len(lines_list) + 0.3)
            attach = getattr(e.dxf, 'attachment_point', 1) if e.dxftype() == 'MTEXT' else 7
            pad_x = ch * 0.4
            pad_y = ch * 0.2
            if attach in (1, 4, 7):
                dx_min, dx_max = -pad_x, est_w + pad_x
            elif attach in (2, 5, 8):
                dx_min, dx_max = -(est_w/2) - pad_x, (est_w/2) + pad_x
            else:
                dx_min, dx_max = -est_w - pad_x, pad_x
            if attach in (1, 2, 3):
                dy_max, dy_min = pad_y, -est_h - pad_y
            elif attach in (4, 5, 6):
                dy_max, dy_min = (est_h/2) + pad_y, -(est_h/2) - pad_y
            else:
                dy_min, dy_max = -pad_y, est_h + pad_y
            dy_center = (dy_min + dy_max) / 2.0
            return {
                'insert': insert, 'rot_rad': rot_rad,
                'dx_min': dx_min, 'dx_max': dx_max,
                'dy_min': dy_min, 'dy_max': dy_max,
                'dy_center': dy_center, 'pad_x': pad_x,
                'ch': ch, 'w': abs(dx_max - dx_min), 'h': abs(dy_max - dy_min)
            }

        def _line_crosses_bbox(lx1, ly1, lx2, ly2, bbox):
            dx_min, dx_max = bbox['dx_min'], bbox['dx_max']
            dy_min, dy_max = bbox['dy_min'], bbox['dy_max']
            ch = bbox['ch']
            w, h = bbox['w'], bbox['h']
            if max(lx1, lx2) < dx_min or min(lx1, lx2) > dx_max: return False
            if max(ly1, ly2) < dy_min or min(ly1, ly2) > dy_max: return False
            dist_sq = (lx2-lx1)**2 + (ly2-ly1)**2
            if dist_sq < 0.1: return False
            if abs(lx2 - lx1) < w * 0.1: return False  # Too vertical
            if abs(ly2 - ly1) < h * 0.1: return False  # Too horizontal
            cx = (dx_min + dx_max) / 2.0
            cy = (dy_min + dy_max) / 2.0
            dist_to_center = abs((lx2-lx1)*(ly1-cy) - (lx1-cx)*(ly2-ly1)) / math.sqrt(dist_sq)
            return dist_to_center < (ch * 2.5)

        # PHASE 1: Collect candidates and detect X lines using only PRE-EXISTING lines
        to_format = []  # list of (entity, bbox, lines_to_delete)

        for e in msp:
            if e.dxftype() not in ('TEXT', 'MTEXT'):
                continue
            if not e.dxf.hasattr('layer'):
                continue
            layer = e.dxf.layer
            is_remover    = 'REMOVER'    in layer.upper()
            is_substituir = 'SUBSTITUIR' in layer.upper()
            # Only process REMOVER and SUBSTITUIR layers - NOT plain IMPLANTAR/EXISTENTE
            if not (is_remover or is_substituir):
                continue

            bbox = _text_bbox(e)
            if bbox is None:
                continue

            insert   = bbox['insert']
            rot_rad  = bbox['rot_rad']

            # Check only against pre-existing lines (snapshot before this pass)
            lines_to_delete = []
            for line in existing_lines:
                line_layer = getattr(line.dxf, 'layer', '')
                line_color = line.dxf.get('color', 256)
                # Only consider deletion markers: red lines or lines on REMOVER/SUBSTITUIR layers
                if not (line_color == 1 or
                        'REMOVER'    in line_layer.upper() or
                        'SUBSTITUIR' in line_layer.upper()):
                    continue
                p1, p2 = line.dxf.start, line.dxf.end
                rx1, ry1 = p1.x - insert.x, p1.y - insert.y
                lx1 = rx1 * math.cos(-rot_rad) - ry1 * math.sin(-rot_rad)
                ly1 = rx1 * math.sin(-rot_rad) + ry1 * math.cos(-rot_rad)
                rx2, ry2 = p2.x - insert.x, p2.y - insert.y
                lx2 = rx2 * math.cos(-rot_rad) - ry2 * math.sin(-rot_rad)
                ly2 = rx2 * math.sin(-rot_rad) + ry2 * math.cos(-rot_rad)
                if _line_crosses_bbox(lx1, ly1, lx2, ly2, bbox):
                    lines_to_delete.append(line)

            has_x = len(lines_to_delete) > 0

            # REMOVER → always format; SUBSTITUIR → only if X found
            if is_remover or has_x:
                to_format.append((e, bbox, lines_to_delete))

        # PHASE 2: Apply formatting and generate strikethrough lines
        for e, bbox, lines_to_delete in to_format:
            layer = e.dxf.layer
            # Gray color
            e.dxf.color = 256
            e.dxf.true_color = (51 << 16) | (51 << 8) | 51

            # Delete the original X lines
            for line in lines_to_delete:
                try:
                    msp.delete_entity(line)
                    linhas_apagadas += 1
                except Exception:
                    pass

            # Generate precise strikethrough
            insert   = bbox['insert']
            rot_rad  = bbox['rot_rad']
            dx_min   = bbox['dx_min']
            dx_max   = bbox['dx_max']
            dy_center = bbox['dy_center']
            pad_x    = bbox['pad_x']

            strike_min_rx = (dx_min - pad_x * 0.5) * math.cos(rot_rad) - dy_center * math.sin(rot_rad)
            strike_min_ry = (dx_min - pad_x * 0.5) * math.sin(rot_rad) + dy_center * math.cos(rot_rad)
            strike_max_rx = (dx_max + pad_x * 0.5) * math.cos(rot_rad) - dy_center * math.sin(rot_rad)
            strike_max_ry = (dx_max + pad_x * 0.5) * math.sin(rot_rad) + dy_center * math.cos(rot_rad)

            p1_world = (insert.x + strike_min_rx, insert.y + strike_min_ry)
            p2_world = (insert.x + strike_max_rx, insert.y + strike_max_ry)

            msp.add_line(p1_world, p2_world, dxfattribs={'layer': layer, 'color': 1})
            strikethroughs_gerados += 1

        print(f"Deleted {linhas_apagadas} X lines and generated {strikethroughs_gerados} strikethroughs for REMOVER/SUBSTITUIR texts.")
            
        # --- FORMATAR LINHAS DE VÃOS (SPANS) ---
        if 'TRACEJADA' not in doc.linetypes:
            try:
                doc.linetypes.new(
                    name='TRACEJADA',
                    dxfattribs={
                        'description': 'Linha Tracejada',
                        'pattern': [1.0, 0.5, -0.5]
                    }
                )
                print("Created linetype 'TRACEJADA' successfully.")
            except Exception as e:
                print(f"Error creating TRACEJADA linetype: {e}")

        formatted_spans_count = 0
        for e in msp:
            if e.dxftype() in ('LINE', 'LWPOLYLINE'):
                if not e.dxf.hasattr('layer'):
                    continue
                layer_upper = e.dxf.layer.upper()
                
                # Rede Primária
                if 'REDE PRIMARIA' in layer_upper:
                    if 'INSTALAR' in layer_upper or 'IMPLANTAR' in layer_upper:
                        e.dxf.color = 1  # Vermelha
                        e.dxf.linetype = 'TRACEJADA'
                    elif 'EXISTENTE' in layer_upper or 'MANTER' in layer_upper:
                        e.dxf.color = 5  # Azul
                        e.dxf.linetype = 'TRACEJADA'
                    elif 'REMOVER' in layer_upper:
                        e.dxf.color = 256
                        e.dxf.true_color = (51 << 16) | (51 << 8) | 51
                        e.dxf.linetype = 'TRACEJADA'
                    formatted_spans_count += 1
                
                # Rede Secundária
                elif 'REDE SECUNDARIA' in layer_upper:
                    if 'INSTALAR' in layer_upper or 'IMPLANTAR' in layer_upper:
                        e.dxf.color = 1  # Vermelha
                        e.dxf.linetype = 'Continuous'
                    elif 'EXISTENTE' in layer_upper or 'MANTER' in layer_upper:
                        e.dxf.color = 256
                        e.dxf.true_color = (0 << 16) | (127 << 8) | 0
                    elif 'REMOVER' in layer_upper:
                        e.dxf.color = 256
                        e.dxf.true_color = (51 << 16) | (51 << 8) | 51
                    formatted_spans_count += 1

        if formatted_spans_count > 0:
            print(f"Formatted {formatted_spans_count} network spanning lines based on layer rules.")

        # Save
        doc.saveas(output_path)
        
        return {
            'output_path': output_path,
            'replacements': replacements,
            'blocks_mapped': len(self.mapping),
            'scale_factor': scale_factor,
            'scaled_entities': scaled_entities,
        }


# Quick test
if __name__ == '__main__':
    br = BlockReplacer()
    br.load_source(r'DXF\923641130.DXF')
    
    print("Source blocks (used in modelspace):")
    for b in br.get_source_blocks():
        print(f"  {b['name']}: {b['count']} instances, layer: {b['layer']}")
    
    print("\nAll source block definitions:")
    for b in br.get_all_source_block_definitions():
        marker = ' ***' if b['is_used'] else ''
        print(f"  {b['name']} ({b['entity_count']} ents){marker}")
    
    br.load_target(r'DXF\BLOCOS.dxf', 'BLOCOS.dxf')
    
    print("\nTarget blocks:")
    for b in br.get_target_blocks():
        print(f"  {b['name']} ({b['entity_count']} ents) in {b['file']}")
