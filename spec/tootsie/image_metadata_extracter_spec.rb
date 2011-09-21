# encoding: utf-8

require 'spec_helper'

describe Tootsie::ImageMetadataExtractor do

  it 'should read EXIF data' do
    extractor = Tootsie::ImageMetadataExtractor.new
    extractor.extract_from_file(
      File.expand_path('../../test_files/BF 0622 1820.tif', __FILE__))
    extractor.metadata['Exif.Image.ImageWidth'][:type].should == 'short'
    extractor.metadata['Exif.Image.ImageWidth'][:value].should == 10
    extractor.metadata['Exif.Image.ImageLength'][:type].should == 'short'
    extractor.metadata['Exif.Image.ImageLength'][:value].should == 10
    extractor.metadata['Exif.Image.ImageDescription'][:type].should == 'ascii'
    extractor.metadata['Exif.Image.ImageDescription'][:value].should == 'Tømmer på vannet ved Krøderen'
  end

  it 'should read IPTC data' do
    extractor = Tootsie::ImageMetadataExtractor.new
    extractor.extract_from_file(
      File.expand_path('../../test_files/BF 0622 1820.tif', __FILE__))
    extractor.metadata['Iptc.Application2.City'][:type].should == 'string'
    extractor.metadata['Iptc.Application2.City'][:value].should == 'Krødsherad'
    extractor.metadata['Iptc.Application2.ObjectName'][:type].should == 'string'
    extractor.metadata['Iptc.Application2.ObjectName'][:value].should == 'Parti fra Krødsherad'
  end

  it 'should read XMP data' do
    extractor = Tootsie::ImageMetadataExtractor.new
    extractor.extract_from_file(
      File.expand_path('../../test_files/BF 0622 1820.tif', __FILE__))
    extractor.metadata['Xmp.dc.description'][:type].should == 'lang_alt'
    extractor.metadata['Xmp.dc.description'][:value].should == 'lang="x-default" Tømmer på vannet ved Krøderen'
    extractor.metadata['Xmp.tiff.YResolution'][:type].should == 'xmp_text'
    extractor.metadata['Xmp.tiff.YResolution'][:value].should == '300'
  end

end
