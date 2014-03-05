//
//  MBXSimplestyle.m
//  MBXMapKit
//
//  Created by Will Snook on 3/5/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXSimplestyle.h"
#import "MBXCacheManager.h"
#import "MBXPointAnnotation.h"

@implementation MBXSimplestyle

- (id)init
{
    self = [super init];
    if (self)
    {
        _cacheManager = [MBXCacheManager sharedCacheManager];
    }
    return self;
}

- (void)setMapID:(NSString *)mapID
{
    _mapID = mapID;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){

        [_cacheManager prepareCacheForMapID:_mapID];

        NSError *fetchError;
        NSData *data;
        data = [_cacheManager proxySimplestyleForMapID:_mapID withError:&fetchError];

        NSError *parseError;
        id markers;
        if (data && !fetchError)
        {
            NSDictionary *simplestyleJSONDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if(!parseError)
            {
                markers = simplestyleJSONDictionary[@"features"];
            }
            else
            {
                if ([_delegate respondsToSelector:@selector(didFailToLoadSimplestyleForMapID:withError:)]) {
                    [_delegate didFailToLoadSimplestyleForMapID:_mapID withError:parseError];
                }
                else
                {
                    NSLog(@"Error parsing simplestyle for map ID %@ (%@)", _mapID, parseError);
                }
            }

        }
        else
        {
            NSLog(@"There was a problem fetching simplestyle JSON for map ID %@ - (%@)", mapID, fetchError);
        }

        // Find point features in the markers dictionary (if there are any) and add them to the map.
        //
        if (markers && [markers isKindOfClass:[NSArray class]])
        {
            id value;

            for (value in (NSArray *)markers)
            {
                if ([value isKindOfClass:[NSDictionary class]])
                {
                    NSDictionary *feature = (NSDictionary *)value;
                    NSString *type = feature[@"geometry"][@"type"];

                    if ([@"Point" isEqualToString:type])
                    {
                        // Only handle point features for now.
                        //
                        NSString *longitude   = feature[@"geometry"][@"coordinates"][0];
                        NSString *latitude    = feature[@"geometry"][@"coordinates"][1];
                        NSString *title       = feature[@"properties"][@"title"];
                        NSString *description = feature[@"properties"][@"description"];
                        NSString *size        = feature[@"properties"][@"marker-size"];
                        NSString *color       = feature[@"properties"][@"marker-color"];
                        NSString *symbol      = feature[@"properties"][@"marker-symbol"];

                        if (longitude && latitude && size && color && symbol)
                        {
                            title = (title ? title : @"");
                            description = (description ? description : @"");

                            MBXPointAnnotation *point = [MBXPointAnnotation new];

                            point.title      = title;
                            point.subtitle   = description;
                            point.coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);

                            NSData *iconData;
                            NSError *iconError;
                            iconData = [_cacheManager proxyMarkerIconSize:size symbol:symbol color:color error:&iconError];

                            if (iconData && !iconError)
                            {
#if TARGET_OS_IPHONE
                                point.image = [[UIImage alloc] initWithData:iconData scale:[[UIScreen mainScreen] scale]];
#else
                                // Making this smart enough to handle a Retina MacBook with a normal dpi external display is complicated.
                                // For now, just default to @1x images and a 1.0 scale.
                                //
                                point.image = [[NSImage alloc] initWithData:iconData];
#endif

                                if (_delegate)
                                {
                                    dispatch_async(dispatch_get_main_queue(), ^(void){
                                        [_delegate didParseSimplestylePoint:point];
                                    });
                                }
                            }

                        }
                        else
                        {
                            NSLog(@"This simplestyle Point feature is missing one or more important keys (%@)", feature);
                        }
                    }
                }
            }
        }
    });
}

- (void)addMarkersJSONDictionaryToMap:(NSDictionary *)markersJSONDictionary
{
}


/*
- (void)addMarkerSize:(NSString *)size symbol:(NSString *)symbol color:(NSString *)color toMapView:(MBXMapView *)mapView
{
    [self.imageTask cancel];

    [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/markers", mapView.cachePath] withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *marker = [MBXPointAnnotation markerStringForSize:size symbol:symbol color:color];
    NSString *makiPinCachePath = [NSString stringWithFormat:@"%@/markers/%@", mapView.cachePath, marker];
    NSString *markerDownloadURL = [NSString stringWithFormat:@"https://a.tiles.mapbox.com/v3/marker/%@", marker];

    NSURL *makiPinURL = ([[NSFileManager defaultManager] fileExistsAtPath:makiPinCachePath] ? [NSURL fileURLWithPath:makiPinCachePath] : [NSURL URLWithString:markerDownloadURL]);

    self.imageTask = [mapView.dataSession dataTaskWithURL:makiPinURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                      {
                          if (error)
                          {
                              NSLog(@"Attempting to load marker icon produced an NSURLSession-level error (%@)", error);
                          }
                          else if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200)
                          {
                              NSLog(@"Attempting to load marker icon failed by receiving an HTTP status %li", (long)((NSHTTPURLResponse *)response).statusCode);
                          }
                          else
                          {
                              // At this point we should have an NSHTTPURLResponse with an HTTP 200, or else an
                              // NSURLResponse with the contents of a file from cache. Both of those are good.
                              //
                              if ([response isKindOfClass:[NSHTTPURLResponse class]])
                              {
                                  [data writeToFile:makiPinCachePath atomically:YES];
                              }
#if TARGET_OS_IPHONE
                              self.image = [[UIImage alloc] initWithData:data scale:[[UIScreen mainScreen] scale]];
#else
                              // Making this smart enough to handle a Retina MacBook with a normal dpi external display is complicated.
                              // For now, just default to @1x images and a 1.0 scale.
                              //
                              self.image = [[NSImage alloc] initWithData:data];
#endif
                              
                              dispatch_sync(dispatch_get_main_queue(), ^(void)
                                            {
                                                [mapView addAnnotation:self];
                                            });
                          }
                      }];
    
    [self.imageTask resume];
}
 */

@end